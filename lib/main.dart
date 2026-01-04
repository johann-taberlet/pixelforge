import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/editor_state.dart';
import 'tools/tool.dart';
import 'ui/screens/editor_screen.dart';

void main() {
  runApp(const PixelForgeApp());
}

class PixelForgeApp extends StatelessWidget {
  const PixelForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EditorState()),
        ChangeNotifierProvider(create: (_) => ToolController()),
      ],
      child: MaterialApp(
        title: 'PixelForge',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF1E1E1E),
          dividerColor: const Color(0xFF3C3C3C),
        ),
        home: const EditorScreen(),
      ),
    );
  }
}
