import 'package:aedove/presentation/widgets/receive/receive_file_path_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiveFilePathHelper', () {
    test('detects explicit gallery saved paths', () {
      expect(
        ReceiveFilePathHelper.isExplicitGallerySavedPath('gallery://photo.jpg'),
        isTrue,
      );
      expect(
        ReceiveFilePathHelper.gallerySavedFileName('gallery://photo.jpg'),
        'photo.jpg',
      );
    });

    test('detects gallery-like paths', () {
      expect(
        ReceiveFilePathHelper.isGalleryPath('content://media/123'),
        isTrue,
      );
      expect(
        ReceiveFilePathHelper.isGalleryPath('/storage/DCIM/photo.jpg'),
        isTrue,
      );
      expect(
        ReceiveFilePathHelper.isGalleryPath('/storage/Documents/file.pdf'),
        isFalse,
      );
    });

    test('shortPath trims long paths', () {
      expect(
        ReceiveFilePathHelper.shortPath('/a/b/c/d/e/f/g.txt'),
        'c/d/e/f/g.txt',
      );
      expect(ReceiveFilePathHelper.shortPath('/a/b/c.txt'), '/a/b/c.txt');
    });
  });
}
