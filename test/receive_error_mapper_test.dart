import 'package:aedove/presentation/pages/tabs/receive_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiveErrorMapper', () {
    test('formats saved-to-gallery message', () {
      expect(
        ReceiveErrorMapper.savedToGalleryMessage('photo.jpg'),
        'photo.jpg saved to gallery. Open your Photos/Gallery app to view.',
      );
    });

    test('returns permission hint for permission text', () {
      expect(
        ReceiveErrorMapper.openFileError(Exception('Permission denied')),
        'Permission denied. Please allow file access and try again.',
      );
    });

    test('returns fallback open file message', () {
      expect(
        ReceiveErrorMapper.openFileError(Exception('unknown')),
        'Error opening file. Please try again.',
      );
      expect(ReceiveErrorMapper.openFileFailure(), 'Could not open file.');
      expect(
        ReceiveErrorMapper.openFileManagerFailure(),
        'Could not open file manager.',
      );
    });
  });
}
