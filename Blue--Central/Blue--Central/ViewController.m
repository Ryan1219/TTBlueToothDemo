//
//  ViewController.m
//  Blue--Central
//
//  Created by zhang liangwang on 16/4/5.
//  Copyright © 2016年 zhangliangwang. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>


static NSString *const kServiceUUID = @"fsfsfs";
static NSString *const kCharacteristicUUID = @"fsfsfsfsfs";
static NSString *const kCharacteristicLocationUUID = @"537B5FD6";

#define BLE_SERVICE_NAME @""

@interface ViewController () <CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic,strong) CBCentralManager *centralManager; //声明一个中心
@property (nonatomic,strong) NSMutableData *data; //存放数据
@property (nonatomic,strong) CBPeripheral *peripheral;//发现的设备
@property (nonatomic,strong) CBCharacteristic *characteristic;//设备特征值
@property (nonatomic,strong) UITextView *textView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    
    //创建中心
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
   
    self.data = [[NSMutableData alloc] init];
    
    
    
    //显示数据
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(100, 100, 240, 300)];
    textView.font = [UIFont systemFontOfSize:14];
    textView.textColor = [UIColor blackColor];
    [self.view addSubview:textView];
    self.textView = textView;
    
}

//页面将要消失时
- (void)viewWillDisappear:(BOOL)animated
{
    [self.centralManager stopScan];
    
    [super viewWillDisappear:animated];
}

#if 0
typedef NS_ENUM(NSInteger, CBCentralManagerState) {
    CBCentralManagerStateUnknown = 0,
    CBCentralManagerStateResetting,
    CBCentralManagerStateUnsupported,
    CBCentralManagerStateUnauthorized,
    CBCentralManagerStatePoweredOff,
    CBCentralManagerStatePoweredOn,
};
#endif

//中心  http://blog.csdn.net/pony_maggie/article/details/26740237
#pragma mark --CBCentralManagerDelegate
//查看app设置是否支持BLE
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    
    if (central.state != CBCentralManagerStatePoweredOn) {
        NSLog(@"central manager did not scan");
        return;
    }
    
    [self scan];
    
    NSLog(@"central manager did scan");
    

}

//开始扫描外设
- (void)scan
{
    //service为对应的ServiceUUID，如果为nil，则为搜索所有的service
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUUID]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
}


//连接外设，发现附带广播数据和信号质量的周边被发现
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    
    //4次添加
    if (RSSI.integerValue > -15) {
        return;
    }
    
    if (RSSI.integerValue < -35) {
        return;
    }
    
    if (self.peripheral != peripheral) {
        self.peripheral = peripheral;
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}


//如果连接外设没有成功
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@ %@",peripheral,error.localizedDescription);
    [self cleanup];
}


//连接外设代理
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{

    //4次添加
    //停止扫描
    [self.centralManager stopScan];
    NSLog(@"stop scanning");
    
    //clear data that we may already have
    [self.data setLength:0];
    
    peripheral.delegate = self;
    
    // Search only for services that match our UUID 只发现匹配UUID的外设
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
}



//周边回调通知
#pragma mark --CBPeripheralDelegate
//发现服务就会执行该代理
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    
    //4次添加
    if (error) {
        
        [self cleanup];
        return;
    }
    
    for (CBService *service in peripheral.services) {
        
        [self.peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:kCharacteristicUUID]] forService:service];
        
        NSLog(@"service found with uuid: %@",service.UUID);


    }
    
    
}


//发现服务特征值更新代理
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    
    //4次添加
    if (error) {
        
        [self cleanup];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUUID]]) {
            
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    
    // Once this is complete, we just need to wait for the data to come in.
}

//与外设进行数据交互，读取更新的特征值代理
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{

    //4
    if (error) {
        NSLog(@"error discover characteristic %@",error.localizedDescription);
        return;
    }
    
    NSString *stringData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
    //???
    if ([stringData isEqualToString:@"EOM"]) {
        
        [self.textView setText:[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]];
        
        // Cancel our subscription to the characteristic
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
    
    // Otherwise, just add the data on to what we already have
    [self.data appendData:characteristic.value];
}

//didUpdateNotificationStateForCharacteristic
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        
    }
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUUID]]) {
        
        return;
    }
    
    // notify has start
    if (characteristic.isNotifying) {
        
//        [peripheral readValueForCharacteristic:characteristic];
    } else { // notify has stop
        
        [self.centralManager cancelPeripheralConnection:self.peripheral];
    }
    
    
}


//没有连接上设备
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    
    self.peripheral = nil;
    
    // so start again
    [self scan];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error == nil) {
        
    } else {
        
    }
}
- (void)cleanup
{
    
    if (self.peripheral.state == CBPeripheralStateDisconnected) {
        return;
    }
    
    if (self.peripheral.services != nil) {
        
        for (CBService *service in self.peripheral.services) {
            
            if (service.characteristics != nil) {
                
                for (CBCharacteristic *characteristic in service.characteristics) {
                    
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUUID]]) {
                        
                        if (characteristic.isNotifying) {
                            
                            [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
                            
                            return;
                        }
                    }
                }
            }
        }
    }
    
    [self.centralManager cancelPeripheralConnection:self.peripheral];
}












































    
    
@end
