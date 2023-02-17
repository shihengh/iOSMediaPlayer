//
//  ViewController.m
//  MediaPlayer
//
//  Created by shimo-imac on 2023/1/19.
//

#import "ViewController.h"
#import "BaseViewController.h"
#import "VideoRenderController.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, strong) UITableView* tableView;
@property(nonatomic, strong) NSMutableArray *datas;
@property(nonatomic, strong) NSMutableArray *titleData;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"MediaPlayer";
    
    self.datas = [NSMutableArray arrayWithObjects:
                  @"VideoRenderController",
                  nil];
    
    self.titleData = [NSMutableArray arrayWithObjects:
                      @"视频播放",
                      nil];
    
    [self.view addSubview:self.tableView];
}

- (void)viewWillLayoutSubviews{
    [super viewWillLayoutSubviews];
//    self.tableView.frame = self.view.frame;
}

#pragma mark - dataSource
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.datas.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if(!cell){
        cell = [tableView cellForRowAtIndexPath:indexPath];
    }
    cell.textLabel.text = self.titleData[indexPath.row];
    return  cell;
}

#pragma mark - delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    Class class = NSClassFromString(self.datas[indexPath.row]);
    if(class){
        BaseViewController *viewController = [[class alloc] init];
        if(viewController){
            viewController.title = self.titleData[indexPath.row];
            if(self.navigationController)
            {
                [self.navigationController pushViewController:viewController animated:YES];
                NSLog(@"[跳转成功：%@]", viewController);
            }
        }
    }
}

- (UITableView *)tableView{
    if(!_tableView){
        _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
    return _tableView;
}

@end
