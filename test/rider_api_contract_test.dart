import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/api/api_client.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/storage/token_storage.dart';
import 'package:likhae/features/rider/deliveries/rider_delivery_models.dart';
import 'package:likhae/features/rider/messages/rider_messages_screen.dart';
import 'package:likhae/features/rider/pickups/rider_pickups_screen.dart';
import 'package:likhae/services/logistics_mobile_service.dart';
import 'package:likhae/services/rider_mobile_service.dart';

// Fixture contract tests, not a running Laravel server. Only loopback is allowed.
// flutter test --dart-define=API_ENABLED=true
// --dart-define=API_BASE_URL=http://127.0.0.1:18764/api/v1 test/rider_api_contract_test.dart
void main() {
  final base = Uri.parse(AppConfig.apiBaseUrl);
  final enabled = AppConfig.apiEnabled && base.host == '127.0.0.1';
  group(
    'Rider and logistics HTTP contracts',
    () {
      late HttpServer server;
      var responseStatus = 200;
      dynamic responseBody;
      final pageResponses = <int, dynamic>{};
      final requests =
          <
            ({String method, String path, String body, Uri uri, String? token})
          >[];
      final pickup = RiderPickupData.fromApi({
        'id': 11,
        'tracking': 'EXPECTED',
        'status': 'IN_PROGRESS',
      });
      final delivery = RiderDeliveryData.fromApi({
        'id': 12,
        'status': 'ASSIGNED',
        'tracking': 'DELIVERY-12',
      });
      const conversation = RiderConversationData(
        id: 'c1',
        buyerId: '31',
        buyerName: 'Buyer',
      );
      Map<String, dynamic> getBody() =>
          Map<String, dynamic>.from(jsonDecode(requests.last.body) as Map);

      setUp(() async {
        FlutterSecureStorage.setMockInitialValues({});
        await TokenStorage.writeToken('test-rider');
        ApiClient.invalidateReads();
        responseStatus = 200;
        responseBody = {'success': true, 'data': {}};
        requests.clear();
        pageResponses.clear();
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, base.port);
        server.listen((request) async {
          requests.add((
            method: request.method,
            path: request.uri.path,
            body: await utf8.decoder.bind(request).join(),
            uri: request.uri,
            token: request.headers.value('authorization'),
          ));
          request.response.statusCode = responseStatus;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(
              pageResponses[int.tryParse(
                    request.uri.queryParameters['page'] ?? '',
                  )] ??
                  responseBody,
            ),
          );
          await request.response.close();
        });
      });
      tearDown(() async {
        await server.close(force: true);
        await TokenStorage.clearToken();
        ApiClient.invalidateReads();
      });

      final reads = <String, Future<dynamic> Function()>{
        'rider/dashboard': RiderMobileService.fetchDashboard,
        'rider/assignments': RiderMobileService.fetchAssignments,
        'rider/pickups': RiderMobileService.fetchPickups,
        'rider/pickups/batches/7': () => RiderMobileService.fetchPickupBatch(7),
        'rider/history': RiderMobileService.fetchHistory,
        'rider/transfers': RiderMobileService.fetchInterHubTransfers,
        'rider/transfers/9': () => RiderMobileService.fetchInterHubTransfer(9),
        'rider/earnings': RiderMobileService.fetchEarnings,
        'rider/profile': RiderMobileService.fetchProfile,
        'rider/notifications': RiderMobileService.fetchNotifications,
        'rider/messages': RiderMobileService.fetchConversations,
        'rider/messages/c1': () =>
            RiderMobileService.fetchMessages(conversation),
      };
      for (final entry in reads.entries) {
        test('GET ${entry.key} parses response and authenticates', () async {
          responseBody = {
            'success': true,
            'data': {
              'id': 7,
              'status': 'IN_PROGRESS',
              'batch_number': 'P-7',
              'rider': {'name': 'Rider', 'is_online': true},
              'user': {'first_name': 'Test', 'last_name': 'Rider'},
              'items': [
                {
                  'id': 11,
                  'tracking': 'TRK-1',
                  'assignment_status': 'COMPLETED',
                },
              ],
            },
          };
          await entry.value();
          expect(requests.single.path, '/api/v1/${entry.key}');
          expect(requests.single.method, 'GET');
          expect(requests.single.token, 'Bearer test-rider');
        });
      }

      test('paginated assignments and pickups include all pages', () async {
        responseBody = {
          'data': {
            'items': [
              {'id': 1},
            ],
          },
          'meta': {'last_page': 2},
        };
        expect(
          (await RiderMobileService.fetchAssignments()).deliveries.length,
          2,
        );
        expect((await RiderMobileService.fetchPickups()).pickups.length, 2);
        expect(requests.map((r) => r.uri.queryParameters['page']), [
          '1',
          '2',
          '1',
          '2',
        ]);
      });

      final actions = <String, Future<void> Function()>{
        'rider/pickups/batches/7/accept': () =>
            RiderMobileService.acceptPickupBatch(7),
        'rider/pickups/batches/7/start': () =>
            RiderMobileService.startPickupBatch(7),
        'rider/pickups/batches/7/finish': () =>
            RiderMobileService.finishPickupBatch(7),
        'rider/transfers/9/accept': () =>
            RiderMobileService.acceptInterHubTransfer(9),
        'rider/notifications/read-all':
            RiderMobileService.markAllNotificationsRead,
        // Client serialization only: this route is missing in the supplied Laravel upload.
        'messages/presence': RiderMobileService.touchMessagePresence,
      };
      for (final entry in actions.entries) {
        test('POST ${entry.key} handles success and rejection', () async {
          await entry.value();
          expect(requests.single.path, '/api/v1/${entry.key}');
          expect(requests.single.method, 'POST');
          responseBody = {'success': false, 'message': 'Rejected by server'};
          await expectLater(entry.value(), throwsA(isA<RiderApiException>()));
        });
      }

      for (final method in ['QR', 'BARCODE', 'MANUAL']) {
        test(
          'batch scan sends $method and requires PICKED_UP confirmation',
          () async {
            responseBody = {
              'success': true,
              'data': {'shipment_status': 'PICKED_UP'},
            };
            await RiderMobileService.scanPickupBatch(
              7,
              ' TRK-1 ',
              scanMethod: method,
            );
            expect(getBody(), {
              'tracking_code': 'TRK-1',
              'scan_method': method,
            });
            responseBody = {
              'success': true,
              'data': {'shipment_status': 'READY'},
            };
            await expectLater(
              RiderMobileService.scanPickupBatch(7, 'TRK-1'),
              throwsFormatException,
            );
          },
        );
      }

      test('not collected sends assignment ID and trimmed reason', () async {
        await RiderMobileService.markPickupNotCollected(
          batchId: 7,
          assignmentId: 11,
          reason: ' unavailable ',
        );
        expect(getBody(), {'rider_assignment_id': 11, 'reason': 'unavailable'});
        expect(
          requests.single.path,
          '/api/v1/rider/pickups/batches/7/not-collected',
        );
      });
      test(
        'transfer decline and start submit reason and scanned item map',
        () async {
          await RiderMobileService.declineInterHubTransfer(9, ' unavailable ');
          expect(getBody(), {'reason': 'unavailable'});
          await RiderMobileService.startInterHubTransfer(9, {
            21: ' TRK-1 ',
          }, scanMethod: 'BARCODE');
          expect(getBody(), {
            'scanned_codes': {'21': 'TRK-1'},
            'scan_method': 'BARCODE',
          });
        },
      );
      test(
        'single pickup verify then complete uses actual scanned value and method',
        () async {
          responseBody = {
            'data': {'verified': true},
          };
          expect(
            await RiderMobileService.verifyPickup(pickup, ' ACTUAL '),
            isTrue,
          );
          expect(getBody(), {'tracking_code': 'ACTUAL'});
          responseBody = {
            'success': true,
            'data': {
              'id': 7,
              'batch_number': 'P-7',
              'status': 'IN_PROGRESS',
              'shipment_status': 'PICKED_UP',
            },
          };
          await RiderMobileService.transitionPickup(
            RiderPickupTransitionRequest(
              pickup: pickup,
              status: 'picked_up',
              scannedCode: ' ACTUAL ',
              scanMethod: 'QR',
            ),
          );
          expect(getBody(), {'tracking_code': 'ACTUAL', 'scan_method': 'QR'});
          expect(requests.last.method, 'POST');
          expect(requests.last.path, '/api/v1/rider/pickups/batches/7/scan');
          expect(requests[1].path, '/api/v1/rider/pickups/11/batch');
        },
      );
      test(
        'single pickup rejects unsupported or unscanned completion before writes',
        () async {
          for (final status in ['unknown', 'picked_up']) {
            await expectLater(
              RiderMobileService.transitionPickup(
                RiderPickupTransitionRequest(pickup: pickup, status: status),
              ),
              throwsFormatException,
            );
          }
          expect(requests, isEmpty);
        },
      );
      test('single pickup accept and start actions', () async {
        responseBody = {
          'success': true,
          'data': {'id': 7, 'batch_number': 'P-7', 'status': 'LOADING'},
        };
        final assigned = RiderPickupData.fromApi({
          'id': 11,
          'status': 'ASSIGNED',
        });
        await RiderMobileService.transitionPickup(
          RiderPickupTransitionRequest(pickup: assigned, status: 'in_progress'),
        );
        expect(requests.where((r) => r.method == 'POST').map((r) => r.path), [
          '/api/v1/rider/pickups/batches/7/accept',
          '/api/v1/rider/pickups/batches/7/start',
        ]);
      });

      for (final entry in {
        'accepted': 'accept',
        'in_transit': 'start',
        'out for delivery': 'start',
        'rejected': 'reject',
        'failed': 'delivery_failed',
        'delivery_failed': 'delivery_failed',
      }.entries) {
        test('delivery ${entry.key} maps to ${entry.value}', () async {
          await RiderMobileService.transitionDelivery(
            RiderDeliveryTransitionRequest(
              delivery: delivery,
              status: entry.key,
              note: 'Reason',
            ),
          );
          expect(getBody()['action'], entry.value);
          expect(requests.single.path, '/api/v1/rider/assignments/12');
          expect(requests.single.method, 'PATCH');
        });
      }
      test(
        'delivery rejects missing failure reason or delivery proof',
        () async {
          for (final status in [
            'rejected',
            'failed',
            'delivery_failed',
            'delivered',
            'picked_up',
          ]) {
            await expectLater(
              RiderMobileService.transitionDelivery(
                RiderDeliveryTransitionRequest(
                  delivery: delivery,
                  status: status,
                ),
              ),
              throwsFormatException,
            );
          }
          expect(requests, isEmpty);
        },
      );
      test(
        'delivery success uploads proof with Laravel PATCH override',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'rider-proof-test',
          );
          try {
            final proof = await File(
              '${directory.path}/proof.jpg',
            ).writeAsBytes([1, 2, 3]);
            await RiderMobileService.transitionDelivery(
              RiderDeliveryTransitionRequest(
                delivery: delivery,
                status: 'delivered',
                receiverName: 'Receiver',
                proofPath: proof.path,
                collectedAmount: '125.50',
                scannedCode: 'DELIVERY-12',
                scanMethod: 'BARCODE',
              ),
            );
            expect(requests.single.method, 'POST');
            for (final value in [
              'proof_file',
              '_method',
              'PATCH',
              'delivery_success',
              'Receiver',
              'scanned_code',
              'DELIVERY-12',
              'scan_method',
              'BARCODE',
              'collected_amount',
              '125.50',
            ]) {
              expect(requests.single.body, contains(value));
            }
          } finally {
            await directory.delete(recursive: true);
          }
        },
      );

      test('earnings preserves shares awaiting allocation', () async {
        responseBody = {
          'success': true,
          'data': {
            'items': [
              {'reference': 'PENDING', 'amount': null, 'status': 'Pending'},
              {
                'reference': 'ALLOCATED',
                'amount': '25.50',
                'status': 'Approved',
              },
              {'reference': 'PAID', 'amount': '10.00', 'status': 'Paid'},
            ],
            'rider': {'name': 'Rider'},
          },
        };
        final earnings = await RiderMobileService.fetchEarnings();
        expect(earnings.summary.total, 35.50);
        expect(earnings.summary.paid, 10);
        expect(earnings.summary.pending, 25.50);
        expect(earnings.summary.unallocatedCount, 1);
      });

      test('delivery cannot submit a missing or wrong parcel scan', () async {
        for (final code in [null, '', 'OTHER-PARCEL']) {
          await expectLater(
            RiderMobileService.transitionDelivery(
              RiderDeliveryTransitionRequest(
                delivery: delivery,
                status: 'delivered',
                receiverName: 'Receiver',
                proofPath: 'unused.jpg',
                collectedAmount: '10.00',
                scannedCode: code,
              ),
            ),
            throwsFormatException,
          );
        }
        expect(requests, isEmpty);
      });

      test('pickup batch ownership failure sends no write', () async {
        responseStatus = 404;
        responseBody = {'success': false, 'message': 'Batch not found'};
        await expectLater(
          RiderMobileService.transitionPickup(
            RiderPickupTransitionRequest(pickup: pickup, status: 'in_progress'),
          ),
          throwsA(isA<RiderApiException>()),
        );
        expect(requests.single.method, 'GET');
      });

      test(
        'remittances loads nested pagination and preserves unverified amount',
        () async {
          Map<String, dynamic> page(int id, int number) => {
            'success': true,
            'data': {
              'schema_ready': true,
              'collections': [
                {'id': 8, 'tracking': 'TRK-8', 'collected_amount': '100.25'},
              ],
              'remittances': [
                {
                  'id': id,
                  'reference': 'REM-$id',
                  'status': 'SUBMITTED',
                  'expected_amount': '100.25',
                  'submitted_amount': '100.25',
                  'verified_amount': null,
                },
              ],
              'meta': {'current_page': number, 'last_page': 2},
            },
          };
          responseBody = page(2, 1);
          pageResponses[2] = page(1, 2);
          final snapshot = await RiderMobileService.fetchRemittances();
          expect(snapshot.collections.single.collectedAmount, 100.25);
          expect(snapshot.history.map((r) => r.id), [2, 1]);
          expect(snapshot.history.first.verifiedAmount, isNull);
          expect(requests.length, 2);
        },
      );

      test(
        'remittance sends one parcel and exact decimal amount; rejects server failures',
        () async {
          responseBody = {
            'success': true,
            'data': {
              'id': 4,
              'reference': 'REM-4',
              'status': 'SUBMITTED',
              'expected_amount': 100.25,
              'submitted_amount': 100.25,
            },
          };
          final receipt = await RiderMobileService.submitRemittance(
            collectionId: 8,
            amount: ' 100.25 ',
            notes: ' cash ',
          );
          expect(receipt.reference, 'REM-4');
          expect(getBody(), {
            'collection_ids': [8],
            'submitted_amount': '100.25',
            'notes': 'cash',
          });
          expect(requests.single.path, '/api/v1/rider/remittances');
          responseStatus = 422;
          responseBody = {'success': false, 'message': 'Already remitted'};
          await expectLater(
            RiderMobileService.submitRemittance(
              collectionId: 8,
              amount: '99.00',
            ),
            throwsA(isA<RiderApiException>()),
          );
        },
      );

      test('remittance rejects invalid money before writing', () async {
        for (final amount in ['', '-1', '1.234', 'NaN']) {
          await expectLater(
            RiderMobileService.submitRemittance(
              collectionId: 8,
              amount: amount,
            ),
            throwsFormatException,
          );
        }
        expect(requests, isEmpty);
      });

      test('availability online/offline and location updates', () async {
        for (final online in [true, false]) {
          responseBody = {
            'data': {'is_online': online},
          };
          expect(
            await RiderMobileService.updateAvailability(
              online,
              latitude: 14.5,
              longitude: 121,
            ),
            online,
          );
          expect(getBody(), {
            'is_online': online,
            'latitude': 14.5,
            'longitude': 121.0,
          });
          expect(requests.last.method, 'PATCH');
        }
        await RiderMobileService.updateAvailabilityLocation(
          latitude: 14.5,
          longitude: 121,
        );
        expect(requests.last.path, '/api/v1/rider/availability/location');
        responseBody = {'success': true};
        await expectLater(
          RiderMobileService.updateAvailability(true),
          throwsFormatException,
        );
      });
      test(
        'assignment GPS sends UTC timestamp, accuracy and coordinates',
        () async {
          await RiderMobileService.updateLiveLocation(
            assignmentId: 12,
            latitude: 14.5,
            longitude: 121,
            accuracy: 4,
            recordedAt: DateTime.utc(2026, 10, 30),
          );
          expect(getBody(), {
            'latitude': 14.5,
            'longitude': 121.0,
            'accuracy': 4.0,
            'recorded_at': '2026-10-30T00:00:00.000Z',
          });
        },
      );
      test(
        'profile edit/photo and password serialize correctly (backend routes missing)',
        () async {
          await RiderMobileService.updateProfile(
            firstName: 'Test',
            lastName: 'Rider',
            email: 'rider@example.test',
            contactNumber: '09123456789',
          );
          expect(requests.last.method, 'PATCH');
          expect(getBody()['first_name'], 'Test');
          await RiderMobileService.updateProfile(
            firstName: 'Test',
            lastName: 'Rider',
            email: 'rider@example.test',
            contactNumber: '09123456789',
            profilePhotoBytes: Uint8List.fromList([1, 2, 3]),
          );
          expect(requests.last.method, 'POST');
          expect(requests.last.body, contains('profile_photo'));
          expect(requests.last.body, contains('PATCH'));
          await RiderMobileService.updatePassword(
            currentPassword: 'old-test',
            newPassword: 'new-test',
          );
          expect(getBody(), {
            'current_password': 'old-test',
            'password': 'new-test',
            'password_confirmation': 'new-test',
          });
        },
      );
      test('vehicle plate and residential address updates', () async {
        responseBody = {
          'data': {'plate_number': 'ABC123'},
        };
        expect(
          await RiderMobileService.updateVehiclePlate(' abc123 '),
          'ABC123',
        );
        expect(getBody(), {'plate_number': 'ABC123'});
        await RiderMobileService.updateResidentialAddress({
          'barangay_id': 10,
          'street_address': 'Street',
        });
        final addressWrite = requests.singleWhere(
          (request) => request.path.endsWith('/profile/address'),
        );
        expect(addressWrite.method, 'PATCH');
        expect(jsonDecode(addressWrite.body)['barangay_id'], 10);
        expect(requests.last.path, '/api/v1/rider/profile');
        responseBody = {'data': {}};
        await expectLater(
          RiderMobileService.updateVehiclePlate('ABC123'),
          throwsFormatException,
        );
      });
      test('message send and invalid conversation', () async {
        responseBody = {
          'data': {'id': 'm1', 'body': 'Hello', 'from_rider': true},
        };
        expect(
          (await RiderMobileService.sendMessage(conversation, 'Hello')).id,
          'm1',
        );
        expect(getBody(), {
          'conversation_id': 'c1',
          'recipient_id': 31,
          'body': 'Hello',
        });
        await expectLater(
          RiderMobileService.fetchMessages(
            const RiderConversationData(id: '', buyerId: '', buyerName: ''),
          ),
          throwsFormatException,
        );
      });
      for (final status in [401, 403, 404, 422, 500]) {
        test('HTTP $status is surfaced as an error', () async {
          responseStatus = status;
          responseBody = {
            'success': false,
            'message': 'Server rejected request',
          };
          await expectLater(
            RiderMobileService.acceptPickupBatch(7),
            throwsA(isA<RiderApiException>()),
          );
        });
      }
      test('malformed response is not treated as success', () async {
        responseBody = ['not a payload'];
        await expectLater(
          RiderMobileService.acceptPickupBatch(7),
          throwsFormatException,
        );
      });
      test('logistics dashboard and receive QR/BARCODE/MANUAL', () async {
        responseBody = {
          'data': {
            'center': {'name': 'Hub'},
            'summary': {'shipments_in_center': 3, 'scans_today': 1},
            'recent_shipments': [
              {'tracking_number': 'TRK-1', 'status': 'AT_SORTING_CENTER'},
            ],
          },
        };
        final dashboard = await LogisticsMobileService.fetchDashboard();
        expect(dashboard.centerName, 'Hub');
        expect(dashboard.shipmentsInCenter, 3);
        expect(dashboard.recentScans.single.trackingNumber, 'TRK-1');
        for (final method in ['QR', 'BARCODE', 'MANUAL']) {
          responseBody = {
            'success': true,
            'tracking_number': 'TRK-1',
            'current_status': 'AT_SORTING_CENTER',
          };
          expect(
            (await LogisticsMobileService.receiveScannedParcel(
              ' TRK-1 ',
              scanMethod: method,
            )).status,
            'AT_SORTING_CENTER',
          );
          expect(getBody(), {'scanned_code': 'TRK-1', 'scan_method': method});
        }
        responseBody = {'success': false, 'message': 'Not picked up'};
        await expectLater(
          LogisticsMobileService.receiveScannedParcel('TRK-1'),
          throwsException,
        );
        await expectLater(
          LogisticsMobileService.receiveScannedParcel(' '),
          throwsFormatException,
        );
        responseBody = {'success': true};
        await expectLater(
          LogisticsMobileService.receiveScannedParcel('TRK-1'),
          throwsFormatException,
        );
      });
    },
    skip: !enabled
        ? 'Requires API_ENABLED=true and loopback API_BASE_URL.'
        : false,
  );
}
