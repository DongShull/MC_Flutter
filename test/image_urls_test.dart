import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/image/image_urls.dart';
import 'package:mc_flutter/core/session/session_store.dart';

void main() {
  setUpAll(() {
    appSession.debugSeed(baseUrl: 'https://mc.example:99', token: 't');
  });
  group('McImageUrls（对齐 android-core ImageUrls.kt）', () {
    test('相对路径补 /api/v1', () {
      expect(McImageUrls.build('media/9/poster'),
          'https://mc.example:99/api/v1/media/9/poster');
      expect(McImageUrls.build('/media/9/poster'),
          'https://mc.example:99/api/v1/media/9/poster');
    });
    test('/api/ 前缀原样拼接', () {
      expect(McImageUrls.build('/api/v1/media/9/poster'),
          'https://mc.example:99/api/v1/media/9/poster');
    });
    test('绝对地址走 images/proxy', () {
      expect(
          McImageUrls.build('https://tmdb.example/p.jpg'),
          'https://mc.example:99/api/v1/images/proxy?url='
              '${Uri.encodeQueryComponent('https://tmdb.example/p.jpg')}');
    });
    test('宽度阶梯 snap', () {
      expect(McImageUrls.snap(100), 160);
      expect(McImageUrls.snap(5000), 3840);
      expect(McImageUrls.build('a/p', widthPx: 500), 'https://mc.example:99/api/v1/a/p?w=720');
    });
    test('空串/无服务器返回 null', () {
      expect(McImageUrls.build(''), isNull);
      expect(McImageUrls.resolve(null), '');
    });
  });
}
