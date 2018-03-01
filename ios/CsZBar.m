#import "CsZBar.h"
#import <AVFoundation/AVFoundation.h>
#import "AlmaZBarReaderViewController.h"

#pragma mark - State

@interface CsZBar ()
@property bool scanInProgress;
@property NSString *scanCallbackId;
@property AlmaZBarReaderViewController *scanReader;

@end

#pragma mark - Synthesize

@implementation CsZBar

@synthesize scanInProgress;
@synthesize scanCallbackId;
@synthesize scanReader;

#pragma mark - Cordova Plugin

- (void)pluginInitialize {
    self.scanInProgress = NO;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    return;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return NO;
}

#pragma mark - Plugin API

- (void)scan: (CDVInvokedUrlCommand*)command; 
{
    if (self.scanInProgress) {
        [self.commandDelegate
         sendPluginResult: [CDVPluginResult
                            resultWithStatus: CDVCommandStatus_ERROR
                            messageAsString:@"A scan is already in progress."]
         callbackId: [command callbackId]];
    } else {
        self.scanInProgress = YES;
        self.scanCallbackId = [command callbackId];
        self.scanReader = [AlmaZBarReaderViewController new];

        self.scanReader.readerDelegate = self;
        self.scanReader.supportedOrientationsMask = ZBarOrientationMask(UIInterfaceOrientationPortrait);
        self.scanReader.readerView.session.sessionPreset = AVCaptureSessionPreset1280x720;

        [self.scanReader.scanner setSymbology: 0 config: ZBAR_CFG_ENABLE to: 0];
        [self.scanReader.scanner setSymbology: ZBAR_CODE128 config: ZBAR_CFG_ENABLE to: 1];
        
        // Get user parameters
        NSDictionary *params = (NSDictionary*) [command argumentAtIndex:0];
        NSString *camera = [params objectForKey:@"camera"];
        if([camera isEqualToString:@"front"]) {
            // We do not set any specific device for the default "back" setting,
            // as not all devices will have a rear-facing camera.
            self.scanReader.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
        self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;

        NSString *flash = [params objectForKey:@"flash"];
        
        if ([flash isEqualToString:@"on"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        } else if ([flash isEqualToString:@"off"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        }else if ([flash isEqualToString:@"auto"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
        }

//fix for building with iOS 11 SDK and higher
//https://github.com/phongphan/csZBar/commit/b573955650b2fedb022d8192ef6796aeb1fb21e7#diff-95c798d13eb89bab34ce5e45c35c8d75
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 110000
        // Hack to hide the bottom bar's Info button... originally based on http://stackoverflow.com/a/16353530
	NSInteger infoButtonIndex;
        if ([[[UIDevice currentDevice] systemVersion] compare:@"10.0" options:NSNumericSearch] != NSOrderedAscending) {
            infoButtonIndex = 1;
        } else {
            infoButtonIndex = 3;
        }
        UIView *infoButton = [[[[[self.scanReader.view.subviews objectAtIndex:2] subviews] objectAtIndex:0] subviews] objectAtIndex:infoButtonIndex];
        [infoButton setHidden:YES];
#endif
//fix end

        //UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem]; [button setTitle:@"Press Me" forState:UIControlStateNormal]; [button sizeToFit]; [self.view addSubview:button];
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;
        
        BOOL drawSight = [params objectForKey:@"drawSight"] ? [[params objectForKey:@"drawSight"] boolValue] : true;
        UIToolbar *toolbarViewFlash = [[UIToolbar alloc] init];
        
        //The bar length it depends on the orientation
        toolbarViewFlash.frame = CGRectMake(0.0, 0, (screenWidth > screenHeight ?screenWidth:screenHeight), 44.0);
        toolbarViewFlash.barStyle = UIBarStyleBlackOpaque;
        UIBarButtonItem *buttonFlash = [[UIBarButtonItem alloc] initWithTitle:@"Flash" style:UIBarButtonItemStyleDone target:self action:@selector(toggleflash)];
        
        NSArray *buttons = [NSArray arrayWithObjects: buttonFlash, nil];
        [toolbarViewFlash setItems:buttons animated:NO];
        [self.scanReader.view addSubview:toolbarViewFlash];

        if (drawSight) {
            
            //CGFloat dim = screenWidth < screenHeight ? screenWidth / 1.1 : screenHeight / 1.1;
            CGFloat dim = 100;
            //UIView *polygonView = [[UIView alloc] initWithFrame: CGRectMake  ( (screenWidth/2) - (dim/2), (screenHeight/2) - (dim/2), dim, dim)];
            UIView *polygonView = [[UIView alloc] initWithFrame: CGRectMake(0, (screenHeight/2) - (dim/2), screenWidth, dim)];
            polygonView.backgroundColor = [UIColor blackColor];
            polygonView.alpha = 0.1;
            
            /*
            UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(0,(dim / 2) - 100, dim, 100)];
            lineView.backgroundColor = [UIColor blackColor];
            lineView.alpha = 0.1;
            [polygonView addSubview:lineView];*/

            CGFloat x,y,w,h;
            x = polygonView.frame.origin.x / screenWidth;
            y = (polygonView.frame.origin.y + dim) / screenHeight;
            w = polygonView.frame.size.width / screenWidth;
            h = 10 / screenHeight;
/*            
            NSLog(@"x = %f",x);
            NSLog(@"y = %f",y);
            NSLog(@"w = %f",w);
            NSLog(@"h = %f",h);
            
            NSLog(@"pv.x = %f",polygonView.frame.origin.x);
            NSLog(@"pv.y = %f",polygonView.frame.origin.y);
            NSLog(@"pv.w = %f",polygonView.frame.size.width);
            NSLog(@"pv.h = %f",polygonView.frame.size.height);
            
            NSLog(@"sc.w = %f",scanReader.view.frame.size.width);
            NSLog(@"sc.h = %f",scanReader.view.frame.size.height);
            
            NSLog(@"screenWidth = %f",screenWidth);
            NSLog(@"screenHeight = %f",screenHeight);
*/            
            self.scanReader.scanCrop = CGRectMake(y, x, h, w);
            
            self.scanReader.cameraOverlayView = polygonView;
        }

        [self.viewController presentViewController:self.scanReader animated:YES completion:nil];
    }
}

- (void)toggleflash {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    [device lockForConfiguration:nil];
    if (device.torchAvailable == 1) {
        if (device.torchMode == 0) {
            [device setTorchMode:AVCaptureTorchModeOn];
            [device setFlashMode:AVCaptureFlashModeOn];
        } else {
            [device setTorchMode:AVCaptureTorchModeOff];
            [device setFlashMode:AVCaptureFlashModeOff];
        }
    }
    
    [device unlockForConfiguration];
}

#pragma mark - Helpers

- (void)sendScanResult: (CDVPluginResult*)result {
    [self.commandDelegate sendPluginResult: result callbackId: self.scanCallbackId];
}

#pragma mark - ZBarReaderDelegate

- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    return;
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info {
    if ([self.scanReader isBeingDismissed]) {
        return;
    }
    
    id<NSFastEnumeration> results = [info objectForKey: ZBarReaderControllerResults];
    
    ZBarSymbol *symbol = nil;
    for (symbol in results) break; // get the first result

    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_OK
                               messageAsString: symbol.data]];
    }];
}

- (void) imagePickerControllerDidCancel:(UIImagePickerController*)picker {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"cancelled"]];
    }];
}

- (void) readerControllerDidFailToRead:(ZBarReaderController*)reader withRetry:(BOOL)retry {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"Failed"]];
    }];
}

@end
