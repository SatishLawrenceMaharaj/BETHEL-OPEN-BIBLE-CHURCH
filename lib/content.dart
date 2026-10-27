/// Public-domain King James Version excerpts, and app configuration.
/// Sermon schedules, addresses and event dates are not invented.
class Church {
  static const name = 'Bethel Open Bible Church';
  static const shortName = 'BETHEL';
  static const facebook = 'https://www.facebook.com/share/1HcbkQCeVN/';
  static const instagram =
      'https://www.instagram.com/bethelobcbordenarve?dlrf=c3ZlNDF4MzJ0OWVr';
  static const youtube =
      'https://youtube.com/@bethelobcbordenarve?si=kervdRLLlO_c0W6s';
}

class BibleVerse {
  final String id;
  final String reference;
  final String text;
  final String reflection;
  const BibleVerse(this.id, this.reference, this.text, this.reflection);
}

const verses = <BibleVerse>[
  BibleVerse('ps119', 'Psalm 119:105',
      'Thy word is a lamp unto my feet, and a light unto my path.',
      'Ask God to guide one decision today. You may not see the whole road ahead, but you can take the next faithful step.'),
  BibleVerse('isa41', 'Isaiah 41:10',
      'Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness.',
      'When fear feels close, remember that you can lean on God’s presence and strength.'),
  BibleVerse('phil4', 'Philippians 4:13',
      'I can do all things through Christ which strengtheneth me.',
      'Ask Christ for the strength to meet today’s responsibilities with patience and humility.'),
  BibleVerse('ps46', 'Psalm 46:1',
      'God is our refuge and strength, a very present help in trouble.',
      'Whatever your situation, bring your concern to God in prayer.'),
  BibleVerse('prov3', 'Proverbs 3:5',
      'Trust in the LORD with all thine heart; and lean not unto thine own understanding.',
      'Place one unresolved worry in God’s hands today.'),
  BibleVerse('rom8', 'Romans 8:28',
      'And we know that all things work together for good to them that love God, to them who are the called according to his purpose.',
      'Remember that God’s purposes extend beyond any one moment.'),
  BibleVerse('2cor5', '2 Corinthians 5:7',
      '(For we walk by faith, not by sight:)',
      'What is one faithful step you can take even when the outcome is uncertain?'),
  BibleVerse('ps23', 'Psalm 23:1',
      'The LORD is my shepherd; I shall not want.',
      'Take a moment to thank God for His guidance and care.'),
  BibleVerse('matt5', 'Matthew 5:16',
      'Let your light so shine before men, that they may see your good works, and glorify your Father which is in heaven.',
      'Show kindness and compassion to someone around you today.'),
  BibleVerse('josh1', 'Joshua 1:9',
      'Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the LORD thy God is with thee whithersoever thou goest.',
      'You do not face today alone. Draw courage from the promise of God’s presence.'),
];

BibleVerse verseOfDay(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
  return verses[dayOfYear % verses.length];
}
