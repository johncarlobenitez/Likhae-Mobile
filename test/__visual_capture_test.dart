import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/theme/app_theme.dart';
import 'package:likhae/shared/widgets/opening_animation_screen.dart';
import 'theme_consistency_test.dart' show themePages;
void main() {
 testWidgets('capture final theme and motion visuals', (tester) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize=const Size(430,932); tester.view.devicePixelRatio=1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
   for(final e in {'Roboto':'roboto-regular.ttf','MaterialIcons':'materialicons-regular.otf'}.entries) {
    final loader=FontLoader(e.key);loader.addFont(File('C:/flutter/bin/cache/artifacts/material_fonts/${e.value}').readAsBytes().then((v)=>v.buffer.asByteData()));await loader.load();
   }
  });
  final key=GlobalKey();
  ThemeData theme(bool dark) {
   final t=dark ? AppTheme.darkTheme : AppTheme.lightTheme;
   return t.copyWith(textTheme:t.textTheme.apply(fontFamily:'Roboto'),primaryTextTheme:t.primaryTextTheme.apply(fontFamily:'Roboto'));
  }
  Future<void> capture(String name) async {
   await tester.runAsync(() async {
    final image=await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
    await File('build/$name.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();
   });
  }
  for(final dark in [false,true]) {
   for(final name in ['login','home','cart','wishlist','tracking','rider-dashboard','rider-delivery']) {
    await tester.pumpWidget(RepaintBoundary(key:key,child:MaterialApp(debugShowCheckedModeBanner:false,theme:theme(dark),home:themePages[name])));
    await tester.pumpAndSettle();
    await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:80)));
    await tester.pumpAndSettle();
    await capture('theme_${dark?'dark':'light'}_$name');
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
   }
   await tester.pumpWidget(RepaintBoundary(key:key,child:MaterialApp(debugShowCheckedModeBanner:false,theme:theme(dark),home:OpeningAnimationScreen(onFinished:(){}))));
   for(var tick=1; tick<=80; tick++) {
    await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:15)));
    await tester.pump(const Duration(milliseconds:100));
    if([10,23,45,56,72].contains(tick)) await capture('intro_${dark?'dark':'light'}_$tick');
    expect(tester.takeException(),isNull);
   }
   await tester.pumpWidget(const SizedBox());
  }
 });
}
