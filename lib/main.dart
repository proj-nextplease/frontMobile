import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/jobs/jobs_page.dart';

void main() => runApp(const NextPleaseApp());

class NextPleaseApp extends StatelessWidget {
  const NextPleaseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'nextplease',
        debugShowCheckedModeBanner: false,
        theme: buildNpTheme(),
        home: const JobsPage(),
      );
}
