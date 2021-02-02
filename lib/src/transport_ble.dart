import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue/flutter_blue.dart';

import 'transport.dart';

class TransportBLE implements ProvTransport {
  final BluetoothDevice bluetoothDevice;
  final String serviceUUID;
  Map<String, String> nuLookup;
  final Map<String, String> lockupTable;
  List<BluetoothService> services;
  
  static const int CONNECTION_TIMEOUT = 6000;
  static const int DISCOVERY_TIMEOUT = 6000;

  static const PROV_BLE_SERVICE = '021a9004-0382-4aea-bff4-6b3f1c5adfb4';
  static const PROV_BLE_EP = {
    'prov-scan': 'ff50',
    'prov-session': 'ff51',
    'prov-config': 'ff52',
    'proto-ver': 'ff53',
    'custom-data': 'ff54',
  };

  TransportBLE(this.bluetoothDevice,
      {this.serviceUUID = PROV_BLE_SERVICE, this.lockupTable = PROV_BLE_EP}) {
    nuLookup = new Map<String, String>();

    for (var name in lockupTable.keys) {
      var charsInt = int.parse(lockupTable[name], radix: 16);
      var serviceHex = charsInt.toRadixString(16).padLeft(4, '0');
      nuLookup[name] =
          serviceUUID.substring(0, 4) + serviceHex + serviceUUID.substring(8);
    }
  }

  Future<bool> connect() async {
    var isConnected = (await bluetoothDevice.state.first()) == BluetoothDeviceState.connected;
    if (isConnected) {
      return true;
    }
    await bluetoothDevice.connect(autoConnect: false, timeout: Duration(milliseconds: CONNECTION_TIMEOUT)).timeout(Duration(milliseconds: CONNECTION_TIMEOUT + 800));
    services = await bluetoothDevice.services.first;
    if (services == null || services.length == 0){
      services = await bluetoothDevice.discoverServices().timeout(Duration(milliseconds: DISCOVERY_TIMEOUT));
    }
    
    isConnected = (await bluetoothDevice.state.first()) == BluetoothDeviceState.connected;
    return isConnected;
  }
  
  BluetoothCharacteristic findService(String serviceUuid, String charUuid){
    BluetoothService service = services.firstWhere((service) => service.uuid == Guid(serviceUuid));
    return service = service.characteristics.firstWhere((characteristic) => characteristic.uuid == Guid(charUuid));
  }

  Future<Uint8List> sendReceive(String epName, Uint8List data) async {
    BluetoothCharacteristic characteristic = findService(serviceUUID, nuLookup[epName]);
    
    if (data != null && data.length > 0) {
      await characteristic.write(data.toList(), withoutResponse = false);
    }
    
    return Uint8List.fromList(await characteristic.read());
  }

  Future<void> disconnect() async {
    return await bluetoothDevice.disconnect();
  }

  void dispose() {
    print('dispose ble');
  }
}
