import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'content.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const BethelApp());
}

class Ink {
  static const navy = Color(0xFF071426);
  static const deep = Color(0xFF0C1F38);
  static const surface = Color(0xFF14283F);
  static const soft = Color(0xFF1D334C);
  static const gold = Color(0xFFE4C181);
  static const brightGold = Color(0xFFFFDCA2);
  static const muted = Color(0xFFB0BCCD);
  static const pale = Color(0xFFF5F0E7);
}

class PrayerEntry {
  final String id;
  final String text;
  final DateTime date;
  final bool answered;

  const PrayerEntry({
    required this.id,
    required this.text,
    required this.date,
    this.answered = false,
  });

  PrayerEntry copyWith({String? text, bool? answered}) => PrayerEntry(
        id: id,
        text: text ?? this.text,
        date: date,
        answered: answered ?? this.answered,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'date': date.toIso8601String(),
        'answered': answered,
      };

  factory PrayerEntry.fromJson(Map<String, dynamic> json) => PrayerEntry(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        answered: json['answered'] == true,
      );
}

class BethelApp extends StatelessWidget {
  const BethelApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: Church.name,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Ink.navy,
          colorScheme: const ColorScheme.dark(
            primary: Ink.gold,
            secondary: Ink.brightGold,
            surface: Ink.surface,
          ),
          fontFamily: 'Roboto',
          snackBarTheme: SnackBarThemeData(
            backgroundColor: Ink.soft,
            contentTextStyle: const TextStyle(color: Ink.pale),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            behavior: SnackBarBehavior.floating,
          ),
        ),
        home: const BethelShell(),
      );
}

class BethelShell extends StatefulWidget {
  const BethelShell({super.key});

  @override
  State<BethelShell> createState() => _BethelShellState();
}

class _BethelShellState extends State<BethelShell> {
  int _tab = 0;
  Set<String> _saved = {};
  List<PrayerEntry> _prayers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bookmarked_verses_v1') ?? <String>[];
    final raw = prefs.getString('prayer_journal_v1') ?? '[]';
    List<PrayerEntry> journal = [];
    try {
      final data = jsonDecode(raw);
      if (data is List) {
        journal = data
            .whereType<Map>()
            .map((item) => PrayerEntry.fromJson(Map<String, dynamic>.from(item)))
            .where((entry) => entry.id.isNotEmpty && entry.text.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Preserve an empty journal if local data cannot be read.
    }
    if (!mounted) return;
    setState(() {
      _saved = bookmarks.toSet();
      _prayers = journal;
    });
  }

  Future<void> _toggleSave(BibleVerse verse) async {
    final updated = Set<String>.of(_saved);
    if (!updated.add(verse.id)) updated.remove(verse.id);
    setState(() => _saved = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarked_verses_v1', updated.toList());
  }

  Future<void> _persistPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prayer_journal_v1', jsonEncode(_prayers.map((p) => p.toJson()).toList()));
  }

  void _addPrayer(String note, PrayerEntry? existing) {
    if (note.trim().isEmpty) return;
    setState(() {
      if (existing != null) {
        _prayers = _prayers.map((p) => p.id == existing.id ? p.copyWith(text: note.trim()) : p).toList();
      } else {
        _prayers = [
          PrayerEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            text: note.trim(),
            date: DateTime.now(),
          ),
          ..._prayers,
        ];
      }
    });
    _persistPrayers();
  }

  void _toggleAnswered(PrayerEntry prayer) {
    setState(() {
      _prayers = _prayers.map((p) => p.id == prayer.id ? p.copyWith(answered: !p.answered) : p).toList();
    });
    _persistPrayers();
  }

  void _removePrayer(PrayerEntry prayer) {
    setState(() => _prayers.removeWhere((p) => p.id == prayer.id));
    _persistPrayers();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Some devices do not support the external-app URL resolver.
    }
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) _notice('Could not open the link. It was copied instead.');
  }

  Future<void> _copyVerse(BibleVerse verse) async {
    await Clipboard.setData(ClipboardData(text: '“${verse.text}” — ${verse.reference} (KJV)'));
    if (mounted) _notice('Scripture copied.');
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigate(int tab) {
    if (_tab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
  }

  Widget _screen() {
    switch (_tab) {
      case 0:
        return HomeScreen(
          key: const ValueKey('home'),
          verse: verseOfDay(DateTime.now()),
          onNavigate: _navigate,
          onLink: _openLink,
        );
      case 1:
        return WordScreen(
          key: const ValueKey('word'),
          saved: _saved,
          onSave: _toggleSave,
          onCopy: _copyVerse,
        );
      case 2:
        return MessagesScreen(key: const ValueKey('messages'), onLink: _openLink);
      case 3:
        return EventsScreen(key: const ValueKey('events'), onLink: _openLink);
      default:
        return PrayerScreen(
          key: const ValueKey('prayer'),
          prayers: _prayers,
          onUpsert: _addPrayer,
          onToggleAnswered: _toggleAnswered,
          onRemove: _removePrayer,
        );
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Ink.navy,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          // There is deliberately NO AppBar or ActionBar title.
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 340),
                    reverseDuration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.045, 0.018),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _screen(),
                  ),
                ),
                NavBar(tab: _tab, onTap: _navigate),
              ],
            ),
          ),
        ),
      );
}

class NavBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  const NavBar({super.key, required this.tab, required this.onTap});

  static const items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Word'),
    (Icons.play_circle_outline, Icons.play_circle_filled_rounded, 'Messages'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Events'),
    (Icons.favorite_outline, Icons.favorite_rounded, 'Prayer'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Ink.navy,
          border: Border(top: BorderSide(color: Color(0xFF27364A))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: tab == i,
                      button: true,
                      label: '${items[i].$3} tab',
                      child: InkWell(
                        onTap: () => onTap(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: tab == i ? 34 : 26,
                              height: 3,
                              margin: const EdgeInsets.only(bottom: 7),
                              decoration: BoxDecoration(
                                color: tab == i ? Ink.gold : Colors.transparent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Icon(tab == i ? items[i].$2 : items[i].$1,
                                color: tab == i ? Ink.gold : Ink.muted, size: 23),
                            const SizedBox(height: 4),
                            Text(
                              items[i].$3,
                              style: TextStyle(
                                color: tab == i ? Ink.gold : Ink.muted,
                                fontSize: 10.5,
                                fontWeight: tab == i ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class ContentPage extends StatelessWidget {
  final List<Widget> children;
  const ContentPage({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071426), Color(0xFF102742), Ink.navy],
            stops: [0, .48, 1],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 38),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
              ),
            ),
          ),
        ),
      );
}

class BrandHeader extends StatelessWidget {
  final VoidCallback? onAction;
  const BrandHeader({super.key, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            height: 55,
            width: 55,
            decoration: BoxDecoration(
              border: Border.all(color: Ink.gold.withOpacity(.65), width: 1),
              borderRadius: BorderRadius.circular(17),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('B E T H E L', style: TextStyle(
                color: Ink.pale, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2,
              )),
              SizedBox(height: 3),
              Text('O P E N  B I B L E  C H U R C H', style: TextStyle(
                color: Ink.gold, fontSize: 8.3, fontWeight: FontWeight.w700,
              )),
            ]),
          ),
          if (onAction != null)
            IconButton.filledTonal(
              onPressed: onAction,
              tooltip: 'Connect with Bethel',
              style: IconButton.styleFrom(
                backgroundColor: Ink.soft,
                foregroundColor: Ink.gold,
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.auto_awesome_outlined, size: 22),
            ),
        ],
      );
}

class Eyebrow extends StatelessWidget {
  final String label;
  const Eyebrow(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Ink.gold, fontWeight: FontWeight.w800, fontSize: 11,
          letterSpacing: 3.2,
        ),
      );
}

class PageHeading extends StatelessWidget {
  final String eyebrow, title, subtitle;
  const PageHeading({super.key, required this.eyebrow, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(eyebrow),
          const SizedBox(height: 17),
          Text(title, style: const TextStyle(
            color: Ink.pale, fontWeight: FontWeight.w800, fontSize: 34, height: 1.13,
          )),
          const SizedBox(height: 13),
          Text(subtitle, style: const TextStyle(color: Ink.muted, height: 1.55, fontSize: 15)),
        ],
      );
}

class GoldButton extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback onTap;
  final bool secondary;
  const GoldButton({super.key, required this.title, required this.onTap, this.icon, this.secondary = false});

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          backgroundColor: secondary ? Ink.soft.withOpacity(.45) : Ink.gold,
          foregroundColor: secondary ? Ink.pale : Ink.navy,
          side: BorderSide(color: secondary ? Ink.muted.withOpacity(.28) : Ink.gold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          if (icon != null) ...[
            const SizedBox(width: 7), Icon(icon, size: 17),
          ],
        ]),
      );
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool goldBorder;
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(22), this.goldBorder = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF21364E), Color(0xFF12243C)],
          ),
          border: Border.all(
            color: goldBorder ? Ink.gold.withOpacity(.36) : Ink.muted.withOpacity(.13),
          ),
        ),
        child: child,
      );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeading(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 22, color: Ink.pale,
          ))),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: Ink.gold),
              child: Text('$action  →', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      );
}

class HomeScreen extends StatelessWidget {
  final BibleVerse verse;
  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onLink;
  const HomeScreen({super.key, required this.verse, required this.onNavigate, required this.onLink});

  String get greeting {
    final hour = DateTime.now().hour;
    return hour < 12 ? 'Good morning.' : hour < 17 ? 'Good afternoon.' : 'Good evening.';
  }

  @override
  Widget build(BuildContext context) => ContentPage(
        children: [
          BrandHeader(onAction: () => _showConnections(context, onLink)),
          const SizedBox(height: 33),
          const Eyebrow('Welcome home'),
          const SizedBox(height: 18),
          Text('$greeting\nWelcome to Bethel.', style: const TextStyle(
            fontWeight: FontWeight.w800, color: Ink.pale, fontSize: 35, height: 1.16,
          )),
          const SizedBox(height: 18),
          const Text('Rooted in His Word. United in His love.', style: TextStyle(
            color: Ink.muted, fontSize: 15.5, height: 1.5,
          )),
          const SizedBox(height: 28),
          Container(
            height: 254,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Ink.gold.withOpacity(.35)),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(.26), blurRadius: 26, offset: const Offset(0, 14),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(29),
              child: Stack(fit: StackFit.expand, children: [
                Image.asset('assets/images/bethel_emblem.jpg', fit: BoxFit.cover),
                Container(decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x9907162C), Color(0xFF071426)],
                    stops: [.15, .52, 1],
                  ),
                )),
                const Positioned(
                  left: 23, right: 20, bottom: 24,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('F A I T H   ·   C O M M U N I T Y   ·   P U R P O S E',
                        style: TextStyle(color: Ink.brightGold, fontSize: 10.5, fontWeight: FontWeight.w600)),
                    SizedBox(height: 12),
                    Text('Grow in faith.\nWalk in love.', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 29, height: 1.12,
                    )),
                    SizedBox(height: 9),
                    Text('Your church family, wherever life takes you.', style: TextStyle(
                      color: Ink.pale, fontSize: 12.5,
                    )),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 22),
          Wrap(spacing: 12, runSpacing: 12, children: [
            GoldButton(title: "Today's scripture", icon: Icons.north_east_rounded, onTap: () => onNavigate(1)),
            GoldButton(title: "What's happening", secondary: true, onTap: () => onNavigate(3)),
          ]),
          const SizedBox(height: 34),
          SectionHeading('Verse of the day', action: 'Read more', onAction: () => onNavigate(1)),
          const SizedBox(height: 13),
          SurfaceCard(
            goldBorder: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.auto_awesome_rounded, color: Ink.gold, size: 18),
                SizedBox(width: 9),
                Text('DAILY ENCOURAGEMENT', style: TextStyle(
                  color: Ink.gold, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 2,
                )),
              ]),
              const SizedBox(height: 23),
              Text('“${verse.text}”', maxLines: 5, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'serif', color: Ink.pale, fontSize: 25, height: 1.45,
                  )),
              const SizedBox(height: 20),
              Text('${verse.reference}  ·  KJV', style: const TextStyle(
                color: Ink.gold, fontWeight: FontWeight.w700, fontSize: 13,
              )),
            ]),
          ),
          const SizedBox(height: 30),
          SectionHeading('Stay connected', action: 'More', onAction: () => _showConnections(context, onLink)),
          const SizedBox(height: 13),
          SocialRow(onLink: onLink),
          const SizedBox(height: 25),
          const Center(child: Text('FAITH  ·  HOPE  ·  LOVE', style: TextStyle(
            color: Ink.gold, fontSize: 10, letterSpacing: 2.6,
          ))),
        ],
      );
}

void _showConnections(BuildContext context, ValueChanged<String> onLink) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Ink.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.church_outlined, color: Ink.gold, size: 36),
        const SizedBox(height: 14),
        const Text('Connect with Bethel', style: TextStyle(
          fontSize: 23, color: Ink.pale, fontWeight: FontWeight.w800,
        )),
        const SizedBox(height: 11),
        const Text('Follow our church family for worship, videos, and announcements.',
          textAlign: TextAlign.center, style: TextStyle(color: Ink.muted, height: 1.5)),
        const SizedBox(height: 26),
        SocialRow(onLink: (link) {
          Navigator.of(context).pop();
          onLink(link);
        }),
      ])),
    ),
  );
}

class SocialRow extends StatelessWidget {
  final ValueChanged<String> onLink;
  const SocialRow({super.key, required this.onLink});

  @override
  Widget build(BuildContext context) => Row(children: [
        _SocialTile(name: 'Facebook', icon: Icons.facebook,
            onTap: () => onLink(Church.facebook)),
        const SizedBox(width: 9),
        _SocialTile(name: 'Instagram', icon: Icons.camera_alt_outlined,
            onTap: () => onLink(Church.instagram)),
        const SizedBox(width: 9),
        _SocialTile(name: 'YouTube', icon: Icons.smart_display_outlined,
            onTap: () => onLink(Church.youtube)),
      ]);
}

class _SocialTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;
  const _SocialTile({required this.name, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            decoration: BoxDecoration(
              color: Ink.soft.withOpacity(.45),
              border: Border.all(color: Ink.muted.withOpacity(.2)),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(children: [
              Icon(icon, size: 25, color: Ink.gold),
              const SizedBox(height: 8),
              Text(name, style: const TextStyle(
                color: Ink.pale, fontWeight: FontWeight.w600, fontSize: 11,
              )),
            ]),
          ),
        ),
      );
}

class WordScreen extends StatefulWidget {
  final Set<String> saved;
  final ValueChanged<BibleVerse> onSave;
  final ValueChanged<BibleVerse> onCopy;
  const WordScreen({super.key, required this.saved, required this.onSave, required this.onCopy});

  @override
  State<WordScreen> createState() => _WordScreenState();
}

class _WordScreenState extends State<WordScreen> {
  BibleVerse? selected;
  bool bookmarksOnly = false;

  @override
  Widget build(BuildContext context) {
    final current = selected ?? verseOfDay(DateTime.now());
    final visible = bookmarksOnly
        ? verses.where((verse) => widget.saved.contains(verse.id)).toList()
        : verses;
    return ContentPage(children: [
      const BrandHeader(),
      const SizedBox(height: 34),
      const PageHeading(
        eyebrow: 'Daily bread', title: 'A word for today.',
        subtitle: 'Pause, reflect, and let the Word of God speak to your heart.',
      ),
      const SizedBox(height: 26),
      SurfaceCard(
        goldBorder: true,
        padding: const EdgeInsets.fromLTRB(24, 27, 24, 25),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_stories_outlined, color: Ink.gold, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Eyebrow('King James Version')),
            IconButton(
              tooltip: widget.saved.contains(current.id) ? 'Remove saved scripture' : 'Save scripture',
              onPressed: () => widget.onSave(current),
              icon: Icon(
                widget.saved.contains(current.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: Ink.gold,
              ),
            ),
          ]),
          const SizedBox(height: 22),
          Text('“${current.text}”', style: const TextStyle(
            fontSize: 27, height: 1.45, fontFamily: 'serif', color: Ink.pale,
          )),
          const SizedBox(height: 21),
          Text(current.reference, style: const TextStyle(
            color: Ink.gold, fontSize: 14, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 23),
          Container(height: 1, color: Ink.gold.withOpacity(.18)),
          const SizedBox(height: 19),
          const Text('A MOMENT TO REFLECT', style: TextStyle(
            fontWeight: FontWeight.w800, color: Ink.gold, letterSpacing: 1.9, fontSize: 10,
          )),
          const SizedBox(height: 11),
          Text(current.reflection, style: const TextStyle(color: Ink.pale, height: 1.6, fontSize: 14)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => widget.onCopy(current),
            style: TextButton.styleFrom(foregroundColor: Ink.gold, padding: EdgeInsets.zero),
            icon: const Icon(Icons.copy_outlined, size: 17),
            label: const Text('Copy this verse'),
          ),
        ]),
      ),
      const SizedBox(height: 33),
      const SectionHeading('More encouragement'),
      const SizedBox(height: 12),
      Row(children: [
        _FilterChip(label: 'All verses', selected: !bookmarksOnly,
            onTap: () => setState(() => bookmarksOnly = false)),
        const SizedBox(width: 9),
        _FilterChip(label: 'Saved (${widget.saved.length})', selected: bookmarksOnly,
            onTap: () => setState(() => bookmarksOnly = true)),
      ]),
      const SizedBox(height: 18),
      if (visible.isEmpty)
        const SurfaceCard(child: Text(
          'No saved verses yet. Tap the bookmark icon on any scripture to keep it here.',
          style: TextStyle(color: Ink.muted, height: 1.5),
        ))
      else
        ...visible.map((verse) => Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Material(
            color: Ink.soft.withOpacity(.5),
            borderRadius: BorderRadius.circular(19),
            child: InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: () => setState(() => selected = verse),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(children: [
                  const Icon(Icons.menu_book_outlined, color: Ink.gold, size: 22),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(verse.reference, style: const TextStyle(
                      color: Ink.pale, fontWeight: FontWeight.w800, fontSize: 14,
                    )),
                    const SizedBox(height: 6),
                    Text(verse.text, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Ink.muted, height: 1.35, fontSize: 12.5)),
                  ])),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right_rounded, color: Ink.gold),
                ]),
              ),
            ),
          ),
        )),
      const SizedBox(height: 12),
      const Center(child: Text('Scripture quotations: King James Version (KJV)',
          style: TextStyle(color: Ink.muted, fontSize: 10))),
    ]);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label), selected: selected, onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: Ink.gold,
        backgroundColor: Ink.soft,
        labelStyle: TextStyle(
          color: selected ? Ink.navy : Ink.pale, fontWeight: FontWeight.w700, fontSize: 12,
        ),
        side: BorderSide(color: selected ? Ink.gold : Ink.muted.withOpacity(.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      );
}

class MessagesScreen extends StatelessWidget {
  final ValueChanged<String> onLink;
  const MessagesScreen({super.key, required this.onLink});

  @override
  Widget build(BuildContext context) => ContentPage(children: [
    BrandHeader(onAction: () => _showConnections(context, onLink)),
    const SizedBox(height: 34),
    const PageHeading(
      eyebrow: 'Be encouraged', title: 'Messages of hope.',
      subtitle: 'Stay rooted in God’s Word with teaching and worship from our church family.',
    ),
    const SizedBox(height: 30),
    SurfaceCard(
      goldBorder: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            image: const DecorationImage(
              image: AssetImage('assets/images/bethel_emblem.jpg'), fit: BoxFit.cover,
            ),
          ),
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(color: Ink.navy.withOpacity(.75), shape: BoxShape.circle),
            padding: const EdgeInsets.all(15),
            child: const Icon(Icons.play_arrow_rounded, color: Ink.gold, size: 42),
          ),
        ),
        const SizedBox(height: 24),
        const Eyebrow('Official YouTube channel'),
        const SizedBox(height: 11),
        const Text('Watch. Grow. Be inspired.', style: TextStyle(
          color: Ink.pale, fontWeight: FontWeight.w800, fontSize: 24,
        )),
        const SizedBox(height: 10),
        const Text('Visit Bethel’s YouTube channel for available videos and worship content.',
            style: TextStyle(color: Ink.muted, height: 1.5)),
        const SizedBox(height: 21),
        GoldButton(title: 'Open YouTube channel', icon: Icons.open_in_new,
          onTap: () => onLink(Church.youtube)),
      ]),
    ),
    const SizedBox(height: 30),
    const SectionHeading('More ways to connect'),
    const SizedBox(height: 14),
    _LinkRow(icon: Icons.facebook, title: 'Church updates on Facebook',
        subtitle: 'Photos, announcements and community', onTap: () => onLink(Church.facebook)),
    const SizedBox(height: 12),
    _LinkRow(icon: Icons.camera_alt_outlined, title: 'Follow us on Instagram',
        subtitle: 'Moments from our church family', onTap: () => onLink(Church.instagram)),
    const SizedBox(height: 23),
    const Text('Videos appear on the official channel. This app does not invent sermon recordings or titles.',
      style: TextStyle(color: Ink.muted, fontSize: 11, height: 1.5)),
  ]);
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _LinkRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Ink.soft.withOpacity(.55),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18), onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
        Icon(icon, size: 25, color: Ink.gold),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Ink.pale, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Ink.muted, fontSize: 12)),
        ])),
        const Icon(Icons.north_east_rounded, color: Ink.gold, size: 18),
      ])),
    ),
  );
}

class EventsScreen extends StatelessWidget {
  final ValueChanged<String> onLink;
  const EventsScreen({super.key, required this.onLink});

  @override
  Widget build(BuildContext context) => ContentPage(children: [
    BrandHeader(onAction: () => _showConnections(context, onLink)),
    const SizedBox(height: 34),
    const PageHeading(
      eyebrow: 'Life together', title: 'Gather. Grow. Belong.',
      subtitle: 'Church is more than a place. It’s a community walking together in faith.',
    ),
    const SizedBox(height: 28),
    SurfaceCard(
      goldBorder: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.calendar_month_outlined, color: Ink.gold, size: 35),
        const SizedBox(height: 16),
        const Text('Stay in the know.', style: TextStyle(
          color: Ink.pale, fontSize: 23, fontWeight: FontWeight.w800,
        )),
        const SizedBox(height: 11),
        const Text('Confirmed event dates and service times have not yet been added to this app. For the latest church announcements, visit our official Facebook page.',
          style: TextStyle(color: Ink.muted, height: 1.55, fontSize: 14)),
        const SizedBox(height: 22),
        GoldButton(title: 'View church announcements', icon: Icons.open_in_new,
          onTap: () => onLink(Church.facebook)),
      ]),
    ),
    const SizedBox(height: 30),
    const SectionHeading('Community & fellowship'),
    const SizedBox(height: 15),
    const _CommunityCard(icon: Icons.church_outlined, title: 'Worship together',
      subtitle: 'Praise, prayer and the Word of God.'),
    const SizedBox(height: 11),
    const _CommunityCard(icon: Icons.volunteer_activism_outlined, title: 'Prayer & fellowship',
      subtitle: 'Encouraging one another in Christ.'),
    const SizedBox(height: 11),
    const _CommunityCard(icon: Icons.groups_outlined, title: 'Grow together',
      subtitle: 'Building faith across generations.'),
    const SizedBox(height: 20),
    const Text('These are examples of ministry activities, not scheduled events.',
      style: TextStyle(color: Ink.muted, fontSize: 11, height: 1.5)),
  ]);
}

class _CommunityCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _CommunityCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(17),
    child: Row(children: [
      Container(
        decoration: BoxDecoration(color: Ink.gold.withOpacity(.12), borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.all(13),
        child: Icon(icon, color: Ink.gold, size: 24),
      ),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Ink.pale, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: Ink.muted, fontSize: 12)),
      ])),
    ]),
  );
}

class PrayerScreen extends StatelessWidget {
  final List<PrayerEntry> prayers;
  final void Function(String note, PrayerEntry? original) onUpsert;
  final ValueChanged<PrayerEntry> onToggleAnswered;
  final ValueChanged<PrayerEntry> onRemove;
  const PrayerScreen({
    super.key,
    required this.prayers,
    required this.onUpsert,
    required this.onToggleAnswered,
    required this.onRemove,
  });

  Future<void> _edit(BuildContext context, [PrayerEntry? entry]) async {
    final controller = TextEditingController(text: entry?.text ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Ink.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(27))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24, 13, 24, MediaQuery.viewInsetsOf(sheetContext).bottom + 26,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('A moment with God'),
            const SizedBox(height: 11),
            Text(entry == null ? 'Write your prayer.' : 'Edit your prayer.',
              style: const TextStyle(color: Ink.pale, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('This entry stays privately on your device.',
              style: TextStyle(color: Ink.muted, fontSize: 12)),
            const SizedBox(height: 19),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              minLines: 3,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Ink.pale, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Heavenly Father, today I pray for…',
                hintStyle: const TextStyle(color: Ink.muted),
                filled: true, fillColor: Ink.navy,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: GoldButton(
              title: entry == null ? 'Save prayer' : 'Save changes',
              icon: Icons.check_rounded,
              onTap: () => Navigator.pop(sheetContext, controller.text),
            )),
          ]),
        ),
      ),
    );
    // Wait until the modal's transition finishes before disposing a controller used by its TextField.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
    if (result != null && result.trim().isNotEmpty) onUpsert(result, entry);
  }

  Future<void> _confirmDelete(BuildContext context, PrayerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Ink.surface,
        title: const Text('Delete this prayer?'),
        content: const Text('This removes the entry from your phone. It cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) onRemove(entry);
  }

  @override
  Widget build(BuildContext context) => ContentPage(children: [
    const BrandHeader(),
    const SizedBox(height: 34),
    const PageHeading(
      eyebrow: 'In His presence', title: 'You are not alone.',
      subtitle: 'Make space to pray, reflect, and remember the goodness of God.',
    ),
    const SizedBox(height: 26),
    SurfaceCard(
      goldBorder: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.favorite_rounded, color: Ink.gold, size: 30),
        const SizedBox(height: 13),
        const Text('“God is our refuge and strength, a very present help in trouble.”',
            style: TextStyle(color: Ink.pale, fontFamily: 'serif', fontSize: 22, height: 1.35)),
        const SizedBox(height: 12),
        const Text('PSALM 46:1  ·  KJV', style: TextStyle(
          color: Ink.gold, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 11,
        )),
        const SizedBox(height: 23),
        GoldButton(title: 'Write a prayer', icon: Icons.edit_outlined, onTap: () => _edit(context)),
      ]),
    ),
    const SizedBox(height: 31),
    const SectionHeading('My prayer journal'),
    const SizedBox(height: 10),
    const Row(children: [
      Icon(Icons.lock_outline_rounded, color: Ink.gold, size: 15),
      SizedBox(width: 6),
      Expanded(child: Text('Private on this phone. Not sent to the church.',
        style: TextStyle(color: Ink.muted, fontSize: 11.5))),
    ]),
    const SizedBox(height: 18),
    if (prayers.isEmpty)
      const SurfaceCard(child: Column(children: [
        Icon(Icons.menu_book_outlined, color: Ink.gold, size: 35),
        SizedBox(height: 14),
        Text('A quiet place for your prayers.', textAlign: TextAlign.center,
          style: TextStyle(color: Ink.pale, fontWeight: FontWeight.w800, fontSize: 17)),
        SizedBox(height: 9),
        Text('Write down what is on your heart. You can mark prayers as answered as your journey unfolds.',
          textAlign: TextAlign.center, style: TextStyle(color: Ink.muted, height: 1.5)),
      ]))
    else
      ...prayers.map((entry) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SurfaceCard(
          padding: const EdgeInsets.fromLTRB(18, 17, 13, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(
                '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                style: const TextStyle(color: Ink.gold, fontWeight: FontWeight.w700, fontSize: 11),
              )),
              if (entry.answered) const Text('ANSWERED', style: TextStyle(
                color: Ink.gold, letterSpacing: 1, fontSize: 10, fontWeight: FontWeight.w800,
              )),
            ]),
            const SizedBox(height: 14),
            Text(entry.text, style: TextStyle(
              color: Ink.pale, height: 1.55, fontSize: 14,
              decoration: entry.answered ? TextDecoration.none : null,
            )),
            const SizedBox(height: 13),
            Wrap(spacing: 5, children: [
              TextButton.icon(
                onPressed: () => onToggleAnswered(entry),
                style: TextButton.styleFrom(foregroundColor: Ink.gold, padding: const EdgeInsets.symmetric(horizontal: 8)),
                icon: Icon(entry.answered ? Icons.check_circle : Icons.radio_button_unchecked, size: 18),
                label: Text(entry.answered ? 'Answered' : 'Mark answered', style: const TextStyle(fontSize: 12)),
              ),
              IconButton(icon: const Icon(Icons.edit_outlined, size: 19, color: Ink.muted),
                tooltip: 'Edit prayer', onPressed: () => _edit(context, entry)),
              IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Ink.muted),
                tooltip: 'Delete prayer', onPressed: () => _confirmDelete(context, entry)),
            ]),
          ]),
        ),
      )),
    const SizedBox(height: 22),
    const Text('Your journal is stored locally. Uninstalling the app or clearing its data removes the entries.',
      style: TextStyle(color: Ink.muted, fontSize: 11, height: 1.5)),
  ]);
}
