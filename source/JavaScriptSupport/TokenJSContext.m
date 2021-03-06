//
//  TokenJSContext.m
//  TokenHTMLRender
//
//  Created by 陈雄 on 2017/9/24.
//  Copyright © 2017年 com.feelings. All rights reserved.
//

#import "TokenJSContext.h"
#import "TokenTool.h"
#import "TokenHybridConstant.h"
#import "JSValue+Token.h"
#import "TokenHybridDefine.h"

@interface TokenJSContext()
@end

@implementation TokenJSContext{
    NSInteger _eventValueAliveCount;
}

+(NSDictionary <NSString *,NSDictionary *>*)privateScript{
    static NSMutableDictionary *scriptStore;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        scriptStore = @{}.mutableCopy;
        NSString *scriptName = @"TokenBase";
        NSString *baseScriptPath = [[NSBundle mainBundle] pathForResource:scriptName ofType:@"js"];
        NSString *baseScript     = [NSString stringWithContentsOfFile:baseScriptPath encoding:NSUTF8StringEncoding error:nil];
        NSURL *baseScriptURL     = [NSURL URLWithString:baseScriptPath];
        if (baseScript && baseScriptURL) {
            [scriptStore setObject:@{@"text":baseScript,@"url":baseScriptURL} forKey:scriptName];
        }
    });
    return scriptStore;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self injectSupprotNativeObj];
        _eventValueAliveCount = 0;
        __weak typeof(self) weakSelf = self;
        self.exceptionHandler = ^(JSContext *context, JSValue *exception) {
            context.exception = exception;
            __strong typeof(weakSelf) sSelf = weakSelf;
            if ([sSelf.delegate respondsToSelector:@selector(context:didReceiveLogInfo:)]) {
                NSString *info = [NSString stringWithFormat:@"错误：%@",[exception toString]];
                [sSelf.delegate context:sSelf didReceiveLogInfo:info];
            }
            HybridLog(@"JSContext exception : %@", exception);
        };
    }
    return self;
}

-(void)injectSupprotNativeObj{
    self[@"token"] = [[TokenTool alloc] init];
    [[TokenJSContext privateScript] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSDictionary * _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *text = obj[@"text"];
        NSURL    *url  = obj[@"url"];
        [self evaluateScript:text withSourceURL:url];
    }];
    
    __weak typeof(self) weakSelf = self;
    self[@"receiveLog"] = ^void(JSValue *info){
        __strong typeof(weakSelf) sSelf = weakSelf;
        if ([sSelf.delegate respondsToSelector:@selector(context:didReceiveLogInfo:)]) {
            [sSelf.delegate context:sSelf didReceiveLogInfo:[info toString]];
        }
    };
    
    self[@"setPriviousPageExtension"] = ^void(JSValue *info){
        __strong typeof(weakSelf) sSelf = weakSelf;
        if ([sSelf.delegate respondsToSelector:@selector(context:setPriviousExtension:)]) {
            [sSelf.delegate context:sSelf setPriviousExtension:[info toDictionary]];
        }
    };
}

-(void)pageShow{
    NSString *script = @"if (window.pageShow != undefined){ window.pageShow();}";
    [self evaluateScript:script];
}

-(void)pageClose{
    NSString *script = @"if (window.pageClose != undefined){ window.pageClose();}";
    [self evaluateScript:script];
}

-(void)pageRefresh{
    NSString *script = @"if (window.pageRefresh != undefined){ window.pageRefresh();}";
    [self evaluateScript:script];
}

-(void)keepEventValueAlive:(JSValue *)value{
    _eventValueAliveCount += 1;
    JSValue *function = [self evaluateScript:@"window.keepEventValueAlive"];
    [function callWithArguments:@[@(_eventValueAliveCount),value]];
}

- (void)dealloc
{
    HybridLog(@"TokenJSContext dead");
}

@end
