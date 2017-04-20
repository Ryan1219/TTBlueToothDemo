//
//  ViewController.m
//  Blue--Peripheral
//
//  Created by zhang liangwang on 16/4/5.
//  Copyright © 2016年 zhangliangwang. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

#define  kServiceUUID         @"fsfsfs"
#define  kCharacteristicUUID  @"sfgsgfsfs"
#define  NOTIFY_MTU 20

@interface ViewController () <CBPeripheralManagerDelegate,UITextViewDelegate>


@property (nonatomic,strong) CBPeripheralManager *peripheralManager;
@property (nonatomic,strong) CBMutableCharacteristic *transferCharacteristic;
@property (nonatomic,strong) CBMutableService *transferService;

@property (nonatomic,strong) UITextView *textView;
@property (nonatomic,strong) UISwitch *advertisingSwitch;
@property (nonatomic,strong) NSData *dataToSend;
@property (nonatomic,assign) NSInteger sendDataIndex;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
  
    
    // Start up the CBPeripheralManager
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    
    
    
    [self.advertisingSwitch addTarget:self action:@selector(clickSwitchChange:) forControlEvents:UIControlEventTouchUpInside];
    
}


- (void)viewWillDisappear:(BOOL)animated
{
    //停止广播
    [self.peripheralManager stopAdvertising];
    
    [super viewWillDisappear:animated];
}


#pragma mark --CBPeripheralManagerDelegate
// 更新
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
    
    //start the CBMutableCharacteristic
    self.transferCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kCharacteristicUUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    
    
    //then the service
    self.transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:kServiceUUID] primary:YES];
    
    
    //add characteristic to the service
    self.transferService.characteristics = @[self.transferCharacteristic];
    
    
    //add service to the peripheral manager
    [self.peripheralManager addService:self.transferService];
    
}



/** Catch when someone subscribes to our characteristic, then start sending them data
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    //get the data
    self.dataToSend = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
    
    //reset the index
    self.sendDataIndex = 0;
    
    //start sending
    [self sendData];
    
}


/** Recognise when the central unsubscribes
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"central unsubscribed from characteristic");
}

//发送数据
- (void)sendData
{
    //first =, check if wr're meant to be sending an EOM
    static BOOL sendingEOM = NO;
    
    if (sendingEOM) {
        
        //send it
        BOOL didSend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
        
        if (didSend) {
            
            sendingEOM = NO;
            NSLog(@"send: EOM");
        }
        
        //if didn't send,so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    
    
    //is ther any left to send
    if (self.sendDataIndex >= self.dataToSend.length) {
        return;
    }
    
    BOOL didSend = YES;
    while (didSend) {
        
        // work out how big it shoule be
        NSInteger amountToSend = self.dataToSend.length - self.sendDataIndex;
        
        //can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) amountToSend = NOTIFY_MTU;
        
        //copy out the data we want
        NSData *chunkData = [NSData dataWithBytes:self.dataToSend.bytes + self.sendDataIndex length:amountToSend];
        
        //send it
        didSend = [self.peripheralManager updateValue:chunkData forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
        
        //if it didn't work,drop out and wait for the callback
        if (!didSend) {
            return;
        }
        
        NSString *stringData = [[NSString alloc] initWithData:chunkData encoding:NSUTF8StringEncoding];
        NSLog(@"---%@",stringData);
        self.sendDataIndex += amountToSend;
        
        // was it the last one?
        if (self.sendDataIndex >= self.dataToSend.length) {
            
            sendingEOM = YES;
            
            BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
            
            if (eomSent) {
                //it sent,we're all donw
                sendingEOM = NO;
            }
            
            return;
        }
    }
    
}

/** This callback comes in when the PeripheralManager is ready to send the next chunk of data.
 *  This is to ensure that packets will arrive in the order they are sent
 */

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    // start sending again
    [self sendData];
}



#pragma mark -- UITextViewDeltage
- (void)textViewDidChange:(UITextView *)textView
{
    if (self.advertisingSwitch.on) {
        
        [self.advertisingSwitch setOn:NO];
        [self.peripheralManager stopAdvertising];
    }
}


- (void)textViewDidBeginEditing:(UITextView *)textView
{
    UIBarButtonItem *rightBtn = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    self.navigationItem.rightBarButtonItem = rightBtn;
    
}

- (void)dismissKeyboard
{
    [self.textView resignFirstResponder];
    self.navigationItem.rightBarButtonItem = nil;
}



- (void)clickSwitchChange:(UISwitch *)sender
{
    if (self.advertisingSwitch.on) {
        
        [self.peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:kServiceUUID]]}];
    } else {
        
        [self.peripheralManager stopAdvertising];
    }
}













// 添加服务
//- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
//{
//    if (error == nil) {
//        
//        [self.peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey:@"ICServer",
//                                                   CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:kServiceUUID]]}];
//    }
//}
//







@end


















































































