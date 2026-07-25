#import <UIKit/UIKit.h>

#define sidebarNavController ((UINavigationController *)self.splitViewController.viewControllers[0])
#define sidebarViewController ((LauncherMenuViewController *)sidebarNavController.viewControllers[0])

@interface LauncherMenuViewController : UIViewController

@property(nonatomic) UIButton *accountButton;

- (void)selectAccount:(UIButton *)sender;
- (void)updateAccountInfo;
- (void)displayProgress:(NSString *)status;
- (UIBarButtonItem *)drawAccountButton;

@end
