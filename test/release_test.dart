import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:test/test.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

void main() {
  Future<Directory> reset([bool dontReset = false]) async {
    final cacheDir = await MapCachingManager.normalDirectory;
    if (!dontReset && cacheDir.existsSync())
      cacheDir.deleteSync(recursive: true);
    return cacheDir;
  }

  group('Backend Filesystem Tests:', () {
    test('Properties start empty', () async {
      final Directory parentDirectory = await reset();
      final MapCachingManager mainManager = MapCachingManager(parentDirectory);
      final MapCachingManager secondaryManager =
          MapCachingManager(parentDirectory, 'secondaryStore');

      expect(mainManager.allStoresLengths, null);
      expect(mainManager.allStoresNames, null);
      expect(mainManager.allStoresSizes, null);

      expect(mainManager.storeLength, null);
      expect(mainManager.storeSize, null);
      expect(mainManager.storeName, 'mainStore');

      expect(secondaryManager.storeLength, null);
      expect(secondaryManager.storeSize, null);
      expect(secondaryManager.storeName, 'secondaryStore');

      mainManager.createStore();
      secondaryManager.createStore();

      expect(mainManager.allStoresLengths, 0);
      expect(mainManager.allStoresNames, ['mainStore', 'secondaryStore']);
      expect(mainManager.allStoresSizes, 0);

      expect(mainManager.storeLength, 0);
      expect(mainManager.storeSize, 0);
      expect(mainManager.storeName, 'mainStore');

      expect(secondaryManager.storeLength, 0);
      expect(secondaryManager.storeSize, 0);
      expect(secondaryManager.storeName, 'secondaryStore');
    });

    test('renameStore()', () async {
      final Directory parentDirectory = await reset();
      MapCachingManager mainManager = MapCachingManager(parentDirectory)
        ..createStore();
      MapCachingManager secondaryManager =
          MapCachingManager(parentDirectory, 'secondaryStore')..createStore();

      expect(mainManager.storeName, 'mainStore');
      expect(secondaryManager.storeName, 'secondaryStore');

      mainManager = mainManager.renameStore('renamedMainStore')!;

      expect(mainManager.storeName, 'renamedMainStore');
      expect(secondaryManager.storeName, 'secondaryStore');

      secondaryManager = secondaryManager.renameStore('renamedSecondaryStore')!;

      expect(mainManager.storeName, 'renamedMainStore');
      expect(secondaryManager.storeName, 'renamedSecondaryStore');

      mainManager = mainManager.renameStore('mainStore')!;
      secondaryManager = secondaryManager.renameStore('secondaryStore')!;

      expect(mainManager.storeName, 'mainStore');
      expect(secondaryManager.storeName, 'secondaryStore');
    });

    test('deleteStore() & deleteAllStores()', () async {
      final Directory parentDirectory = await reset();
      MapCachingManager mainManager = MapCachingManager(parentDirectory)
        ..createStore();
      MapCachingManager secondaryManager =
          MapCachingManager(parentDirectory, 'secondaryStore')..createStore();

      expect(mainManager.storeLength, 0);
      expect(secondaryManager.storeLength, 0);

      mainManager.deleteStore();

      expect(mainManager.storeLength, null);
      expect(secondaryManager.storeLength, 0);

      secondaryManager.deleteStore();

      expect(mainManager.storeLength, null);
      expect(secondaryManager.storeLength, null);

      mainManager.createStore();
      secondaryManager.createStore();

      expect(mainManager.storeLength, 0);
      expect(secondaryManager.storeLength, 0);

      mainManager.deleteAllStores();

      expect(mainManager.storeLength, null);
      expect(secondaryManager.storeLength, null);
    });

    test('Use of temporaryDirectory', () async {
      final parentDirectory = await MapCachingManager.normalDirectory;
      if (parentDirectory.existsSync())
        parentDirectory.deleteSync(recursive: true);

      final MapCachingManager mainManager = MapCachingManager(parentDirectory);

      expect(mainManager.allStoresLengths, null);
      expect(mainManager.allStoresNames, null);
      expect(mainManager.allStoresSizes, null);

      expect(mainManager.storeLength, null);
      expect(mainManager.storeSize, null);
      expect(mainManager.storeName, 'mainStore');

      mainManager.createStore();

      expect(mainManager.allStoresLengths, 0);
      expect(mainManager.allStoresNames, ['mainStore']);
      expect(mainManager.allStoresSizes, 0);

      expect(mainManager.storeLength, 0);
      expect(mainManager.storeSize, 0);
      expect(mainManager.storeName, 'mainStore');

      mainManager.deleteAllStores();

      expect(mainManager.allStoresLengths, null);
      expect(mainManager.allStoresNames, null);
      expect(mainManager.allStoresSizes, null);
    });
  });

  group('Download Region Tests:', () {
    test('preventRedownload', () async {
      final Directory parentDirectory = await reset();
      final MapCachingManager mainManager =
          MapCachingManager(parentDirectory, 'preventRedownload');

      final Stream<DownloadProgress> downloadA = StorageCachingTileProvider(
        parentDirectory: parentDirectory,
        storeName: 'preventRedownload',
      ).downloadRegion(
        RectangleRegion(
          LatLngBounds(
            LatLng(51.50263458922777, -0.6815800359919895),
            LatLng(51.48672619988095, -0.6508706762001888),
          ),
        ).toDownloadable(
          1,
          16,
          TileLayerOptions(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
        ),
      );

      await for (DownloadProgress progress in downloadA) {
        print(' A > ' + progress.percentageProgress.toStringAsFixed(2) + '%');
        expect(progress.erroredTiles.length, 0);
      }

      expect(mainManager.storeLength, 78);

      final Stream<DownloadProgress> downloadB = StorageCachingTileProvider(
        parentDirectory: parentDirectory,
        storeName: 'preventRedownload',
      ).downloadRegion(
        RectangleRegion(
          LatLngBounds(
            LatLng(51.50263458922777, -0.6815800359919895),
            LatLng(51.48672619988095, -0.6508706762001888),
          ),
        ).toDownloadable(
          1,
          16,
          TileLayerOptions(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          preventRedownload: true,
        ),
      );

      DownloadProgress? prog;
      await for (DownloadProgress progress in downloadB) prog = progress;

      expect(prog!.completedTiles - prog.erroredTiles.length, 0);
      expect(mainManager.storeLength, 78);

      final Stream<DownloadProgress> downloadC = StorageCachingTileProvider(
        parentDirectory: parentDirectory,
        storeName: 'preventRedownload',
      ).downloadRegion(
        RectangleRegion(
          LatLngBounds(
            LatLng(51.50263458922777, -0.6815800359919895),
            LatLng(51.48672619988095, -0.6508706762001888),
          ),
        ).toDownloadable(
          1,
          16,
          TileLayerOptions(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
        ),
      );

      await for (DownloadProgress progress in downloadC) {
        print(' C > ' + progress.percentageProgress.toStringAsFixed(2) + '%');
        expect(progress.erroredTiles.length, 0);
      }

      expect(mainManager.storeLength, 78);
    }, timeout: Timeout(Duration(minutes: 1)));

    test('compressionQuality', () async {
      final Directory parentDirectory = await reset(true);
      final MapCachingManager mainManager =
          MapCachingManager(parentDirectory, 'compressionQuality');

      final Stream<DownloadProgress> download = StorageCachingTileProvider(
        parentDirectory: parentDirectory,
        storeName: 'compressionQuality',
      ).downloadRegion(
        RectangleRegion(
          LatLngBounds(
            LatLng(51.50263458922777, -0.6815800359919895),
            LatLng(51.48672619988095, -0.6508706762001888),
          ),
        ).toDownloadable(
          1,
          16,
          TileLayerOptions(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          compressionQuality: 50,
        ),
      );

      await for (DownloadProgress progress in download) {
        print(' > ' + progress.percentageProgress.toStringAsFixed(2) + '%');
        expect(progress.erroredTiles.length, 0);
      }

      expect(mainManager.storeLength, 78);
    }, timeout: Timeout(Duration(minutes: 1)));
  });
}