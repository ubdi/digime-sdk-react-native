#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "DMEClient.h"

@interface Digime : RCTEventEmitter <RCTBridgeModule>

  - (void)emitEventWithName:(NSString *)name body:(NSString *) payload;
  - (void)initSDK;
  - (void)authorize;
  - (void)getSessionAccounts;
  - (void)getSessionData;

@end
