#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTLog.h>

@import DigiMeSDK;
#import "Constants.h"

@interface Digime : RCTEventEmitter <RCTBridgeModule>
  @property (nonatomic, strong) DMEPullClient *dmeClient;
  @property (nonatomic, strong) DMEPullConfiguration *configuration;
@end

@implementation Digime
RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents
{
  return @[
    @"fileReceiveSuccess",
    @"nativeLog"
  ];
}

RCT_EXPORT_METHOD(initSDK)
{
  NSLog(@"[digime] SDK inited");

  NSString *appId = APPLICATION_ID;
  NSString *contractId = CONTRACT_ID;
  NSString *p12Filename = P12_FILENAME;
  NSString *p12Password = P12_PASSPHRASE;
  
  self.configuration = [[DMEPullConfiguration alloc] initWithAppId:appId contractId:contractId p12FileName:p12Filename p12Password:p12Password];
  self.configuration.debugLogEnabled = YES;
  self.configuration.guestEnabled = false;
  
  
  self.dmeClient = nil;
  self.dmeClient = [[DMEPullClient alloc] initWithConfiguration:self.configuration];
}

// Authorize
RCT_REMAP_METHOD(authorize,
                 findEventsWithResolver:(RCTPromiseResolveBlock)resolve
rejecter:(RCTPromiseRejectBlock)reject)
{
  RCTLogInfo(@"[digime] Authorize inited");
  
  [self.dmeClient authorizeWithCompletion:^(DMESession * _Nullable session, NSError * _Nullable error) {
      
    if (session == nil)
    {
      RCTLogWarn(@"[digime] Authorization failed %@", error.localizedDescription);
      reject(@"authorizeFail", error.localizedDescription, error);
      return;
    };

    NSDictionary *sessionDict = @{
      @"sessionKey": session.sessionKey
    };

    resolve([self toJsonString:sessionDict]);
  }];
}

// Get Accounts
RCT_REMAP_METHOD(getAccounts,
                 getAccountsWithResolver:(RCTPromiseResolveBlock)resolve
rejecter:(RCTPromiseRejectBlock)reject)
{
  RCTLogInfo(@"[digime] Get Accounts inited");
  
  [self.dmeClient getSessionAccountsWithCompletion:^(DMEAccounts * _Nullable accounts, NSError * _Nullable error) {
      
    if (accounts == nil)
    {
        reject(@"authorizeFail", error.localizedDescription, error);
        return;
    };

    resolve([self toJsonString:accounts.json[@"accounts"]]);
  }];
}

// Get Files
RCT_REMAP_METHOD(getFiles,
                 getFilesWithResolver:(RCTPromiseResolveBlock)resolve
rejecter:(RCTPromiseRejectBlock)reject)
{
  RCTLogInfo(@"[digime] Get Files inited");
  
  [self.dmeClient getSessionDataWithDownloadHandler:^(DMEFile * _Nullable file, NSError * _Nullable error) {
      
      if (file != nil)
      {
        if (file.fileContentAsJSON != nil) {
          NSDictionary *fileDict = @{
            @"fileId" : file.fileId,
            @"json" : file.fileContentAsJSON
          };

          [self sendEventWithName:@"fileReceiveSuccess" body:[self toJsonString:fileDict]];
        } else {
          RCTLogWarn(@"[digime] Retrieved file %@, but it had empty JSON", file.fileId);
        }
      }
      
      if (error != nil)
      {
          NSString *fileId = error.userInfo[kFileIdKey] ?: @"unknown";
          RCTLogWarn(@"[digime] Failed to retrieve content for fileId: < %@ > Error: %@", fileId, error.localizedDescription);
      }
  } completion:^(NSError * _Nullable error) {
      dispatch_async(dispatch_get_main_queue(), ^{
          if (error != nil)
          {
            RCTLogWarn(@"[digime] Client retrieve session data failed: %@", error.localizedDescription);
            reject(@"getFilesFail", error.localizedDescription, error);
          }
          else
          {
            NSDictionary *resolved = @{@"success": @true};
            resolve(resolved);
          }
      });
  }];
}

// Private method to convert Dictionary to JSON string
- (NSString *)toJsonString:(NSDictionary *)dict {
  NSData * jsonData = [NSJSONSerialization  dataWithJSONObject:dict options:0 error:nil];
  NSString * stringifedJson = [[NSString alloc] initWithData:jsonData   encoding:NSUTF8StringEncoding];
  
  return stringifedJson;
}

@end
