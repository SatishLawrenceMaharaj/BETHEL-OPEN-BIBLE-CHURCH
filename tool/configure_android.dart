/// Runs after `flutter create --platforms=android .`.
/// Keeps the generated Flutter Android shell while applying our app's display name.
import 'dart:io';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln('Android files are missing. First run flutter create --platforms=android .');
    exitCode = 1;
    return;
  }
  final original = manifest.readAsStringSync();
  final updated = original.replaceFirst(
    RegExp(r'android:label="[^"]*"'),
    'android:label="Bethel Open Bible Church"',
  );
  if (original == updated && !original.contains('android:label="Bethel Open Bible Church"')) {
    stderr.writeln('Could not find Android app label in AndroidManifest.xml');
    exitCode = 1;
    return;
  }
  manifest.writeAsStringSync(updated);
  stdout.writeln('Configured Android label: Bethel Open Bible Church');
}
