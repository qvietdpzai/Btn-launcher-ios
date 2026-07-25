#import "authenticator/BaseAuthenticator.h"
#import "AccountListViewController.h"
#import "ALTServerConnection.h"
#import "LauncherNavigationController.h"
#import "LauncherMenuViewController.h"
#import "LauncherPreferences.h"
#import "UIKit+hook.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@interface LauncherMenuViewController()
@property(nonatomic) UIButton *launchButton;
@property(nonatomic) UILabel *statusLabel;
@property(nonatomic) UIImageView *logoView;
@end

@implementation LauncherMenuViewController

#define contentNavigationController ((LauncherNavigationController *)self.splitViewController.viewControllers[1])

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppLogo"]];
    self.logoView.contentMode = UIViewContentModeScaleAspectFit;
    self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.logoView];

    self.accountButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.accountButton addTarget:self action:@selector(selectAccount:) forControlEvents:UIControlEventPrimaryActionTriggered];
    self.accountButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.accountButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.accountButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.accountButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.accountButton];

    self.launchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.launchButton setTitle:localize(@"launcher.menu.play", nil) forState:UIControlStateNormal];
    self.launchButton.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    self.launchButton.backgroundColor = [UIColor colorWithRed:54/255.0 green:176/255.0 blue:48/255.0 alpha:1.0];
    self.launchButton.layer.cornerRadius = 12;
    self.launchButton.tintColor = UIColor.whiteColor;
    self.launchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.launchButton addTarget:self action:@selector(launchGame) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self.view addSubview:self.launchButton];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.logoView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.logoView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:40],
        [self.logoView.widthAnchor constraintEqualToConstant:120],
        [self.logoView.heightAnchor constraintEqualToConstant:120],

        [self.accountButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.accountButton.topAnchor constraintEqualToAnchor:self.logoView.bottomAnchor constant:16],
        [self.accountButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.accountButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [self.launchButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.launchButton.topAnchor constraintEqualToAnchor:self.accountButton.bottomAnchor constant:32],
        [self.launchButton.widthAnchor constraintEqualToConstant:200],
        [self.launchButton.heightAnchor constraintEqualToConstant:60],

        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.launchButton.bottomAnchor constant:16],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
    ]];

    [self updateAccountInfo];

    if (getEntitlementValue(@"get-task-allow")) {
        [self displayProgress:localize(@"login.jit.checking", nil)];
        if (isJITEnabled(false)) {
            [self displayProgress:localize(@"login.jit.enabled", nil)];
            [self displayProgress:nil];
        } else {
            [self enableJITWithAltKit];
        }
    } else if (!NSProcessInfo.processInfo.macCatalystApp && !getenv("SIMULATOR_DEVICE_NAME")) {
        [self displayProgress:localize(@"login.jit.fail", nil)];
        [self displayProgress:nil];
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:localize(@"login.jit.fail.title", nil)
            message:localize(@"login.jit.fail.description_unsupported", nil)
            preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* okAction = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:^(id action){
            exit(-1);
        }];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateAccountInfo];
}

- (void)launchGame {
    [contentNavigationController performSelector:@selector(launchMinecraft:) withObject:self.launchButton];
}

- (void)selectAccount:(UIButton *)sender {
    AccountListViewController *vc = [[AccountListViewController alloc] init];
    vc.whenDelete = ^void(NSString* name) {
        if ([name isEqualToString:getPrefObject(@"internal.selected_account")]) {
            BaseAuthenticator.current = nil;
            setPrefObject(@"internal.selected_account", @"");
            [self updateAccountInfo];
        }
    };
    vc.whenItemSelected = ^void() {
        setPrefObject(@"internal.selected_account", BaseAuthenticator.current.authData[@"username"]);
        [self updateAccountInfo];
        if (sender != self.accountButton) {
            [sender sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
        }
    };
    vc.modalPresentationStyle = UIModalPresentationPopover;
    vc.preferredContentSize = CGSizeMake(350, 250);

    UIPopoverPresentationController *popoverController = vc.popoverPresentationController;
    popoverController.sourceView = sender;
    popoverController.sourceRect = sender.bounds;
    popoverController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    popoverController.delegate = vc;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)updateAccountInfo {
    NSDictionary *selected = BaseAuthenticator.current.authData;

    if (selected == nil) {
        [self.accountButton setTitle:localize(@"login.option.select", nil) forState:UIControlStateNormal];
        [self.accountButton setImage:[UIImage imageNamed:@"DefaultAccount"] forState:UIControlStateNormal];
        return;
    }

    BOOL isDemo = [selected[@"username"] hasPrefix:@"Demo."];
    NSString *displayName = [selected[@"username"] substringFromIndex:(isDemo?5:0)];
    BOOL shouldUpdateProfiles = (getenv("DEMO_LOCK")!=NULL) != isDemo;

    unsetenv("DEMO_LOCK");
    setenv("BTN_GAME_DIR", [NSString stringWithFormat:@"%s/Library/Application Support/minecraft", getenv("BTN_HOME")].UTF8String, 1);

    if (isDemo) {
        setenv("DEMO_LOCK", "1", 1);
        setenv("BTN_GAME_DIR", [NSString stringWithFormat:@"%s/.demo", getenv("BTN_HOME")].UTF8String, 1);
    }

    [self.accountButton setTitle:displayName forState:UIControlStateNormal];
    [self.accountButton setImage:[UIImage imageNamed:@"DefaultAccount"] forState:UIControlStateNormal];

    if (shouldUpdateProfiles) {
        [contentNavigationController fetchLocalVersionList];
        [contentNavigationController performSelector:@selector(reloadProfileList)];
    }
}

- (void)displayProgress:(NSString *)status {
    self.statusLabel.text = status;
}

- (UIBarButtonItem *)drawAccountButton {
    return [[UIBarButtonItem alloc] initWithCustomView:self.accountButton];
}

- (void)enableJITWithAltKit {
    [ALTServerManager.sharedManager startDiscovering];
    [ALTServerManager.sharedManager autoconnectWithCompletionHandler:^(ALTServerConnection *connection, NSError *error) {
        if (error) {
            NSLog(@"[AltKit] Could not auto-connect to server. %@", error.localizedRecoverySuggestion);
            [self displayProgress:localize(@"login.jit.fail", nil)];
        }
        [connection enableUnsignedCodeExecutionWithCompletionHandler:^(BOOL success, NSError *error) {
            if (success) {
                NSLog(@"[AltKit] Successfully enabled JIT compilation!");
                [ALTServerManager.sharedManager stopDiscovering];
                [self displayProgress:localize(@"login.jit.enabled", nil)];
            } else {
                NSLog(@"[AltKit] Error enabling JIT: %@", error.localizedRecoverySuggestion);
                [self displayProgress:localize(@"login.jit.fail", nil)];
            }
            [connection disconnect];
        }];
    }];
}

@end
