//
//  AssignmentClientTask.m
//  stack-manager
//
//  Created by Leonardo Murillo on 6/13/14.
//  Copyright (c) 2014 High Fidelity. All rights reserved.
//

#import "AssignmentClientTask.h"
#import "GlobalData.h"

@implementation AssignmentClientTask
@synthesize logView = _logView;
@synthesize instance = _instance;
@synthesize typeName = _typeName;
@synthesize instanceType = _instanceType;
@synthesize instanceDomain = _instanceDomain;
@synthesize stdoutLogOutput = _stdoutLogOutput;
@synthesize stderrLogOutput = _stderrLogOutput;
@synthesize logsAreInView = _logsAreInView;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSFileHandleDataAvailableNotification
                                                  object:instanceStdoutFilehandle];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSFileHandleDataAvailableNotification
                                                  object:instanceStderrorFileHandle];
}

- (id)initWithType:(NSInteger)thisInstanceType
            domain:(NSString *)thisInstanceDomain
{
    self = [super init];
    if (self) {
        switch ((int)thisInstanceType) {
            case 0:
                _typeName = @"audio-mixer";
                break;
            case 1:
                _typeName = @"avatar-mixer";
                break;
            case 3:
                _typeName = @"voxel-server";
                break;
            case 4:
                _typeName = @"particle-server";
                break;
            case 5:
                _typeName = @"metavoxel-server";
                break;
            case 6:
                _typeName = @"model-server";
                break;
        }
        _instance = [[NSTask alloc] init];
        instanceStdoutPipe = [NSPipe pipe];
        instanceStdoutFilehandle = [instanceStdoutPipe fileHandleForReading];
        instanceStderrorPipe = [NSPipe pipe];
        instanceStderrorFileHandle = [instanceStderrorPipe fileHandleForReading];
        _instanceType = thisInstanceType;
        _instanceDomain = thisInstanceDomain;
        NSMutableArray *assignmentArguments = [NSMutableArray arrayWithObjects:
                                               @"-t",
                                               [NSString stringWithFormat:@"%d", (int)_instanceType],
                                               @"-a",
                                               _instanceDomain,
                                               nil];
        
        [_instance setLaunchPath: [GlobalData sharedGlobalData].assignmentClientExecutablePath];
        [_instance setArguments: assignmentArguments];
        [_instance setCurrentDirectoryPath:[GlobalData sharedGlobalData].clientsLaunchPath];
        [_instance setStandardOutput: instanceStdoutPipe];
        [_instance setStandardError: instanceStderrorPipe];
        [_instance setStandardInput: [NSPipe pipe]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appendAndRotateStdoutLogs:)
                                                     name:NSFileHandleDataAvailableNotification
                                                   object:instanceStdoutFilehandle];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appendAndRotateStderrLogs:)
                                                     name:NSFileHandleDataAvailableNotification
                                                   object:instanceStderrorFileHandle];
        
        [instanceStdoutFilehandle waitForDataInBackgroundAndNotify];
        [instanceStderrorFileHandle waitForDataInBackgroundAndNotify];
        
        _stdoutLogOutput = [[NSMutableArray alloc] init];
        _stderrLogOutput = [[NSMutableArray alloc] init];
        _logsAreInView = NO;
    }
    return self;
}

- (void)displayLog
{
    _logView = [[LogViewer alloc] initWithWindowNibName:@"LogViewer"];
    NSString *typeName = [[NSString alloc] init];
    switch ((int)self.instanceType) {
        case 0:
            typeName = @"audio-mixer";
            break;
        case 1:
            typeName = @"avatar-mixer";
            break;
        case 3:
            typeName = @"voxel-server";
            break;
        case 4:
            typeName = @"particle-server";
            break;
        case 5:
            typeName = @"metavoxel-server";
            break;
        case 6:
            typeName = @"model-server";
            break;
    }
    [[_logView stdoutTextField] setString:@""];
    [[_logView assignmentTypeLabel] setStringValue:typeName];
    self.logsAreInView = YES;
    [_logView showWindow:self];
    for (NSString *stdoutLine in self.stdoutLogOutput) {
        [[[_logView stdoutTextField] textStorage] appendAttributedString:[[NSAttributedString alloc]
                                                                      initWithString:stdoutLine]];
        [[_logView stdoutTextField] scrollRangeToVisible:NSMakeRange([[[_logView stdoutTextField] string] length], 0)];
    }
    for (NSString *stderrLine in self.stderrLogOutput) {
        [[[_logView stderrTextField] textStorage] appendAttributedString:[[NSAttributedString alloc]
                                                                      initWithString:stderrLine]];
        [[_logView stderrTextField] scrollRangeToVisible:NSMakeRange([[[_logView stderrTextField] string] length], 0)];
    }
}

- (void)appendAndRotateStdoutLogs:(NSNotification *)notification
{
    NSInteger maxScrollBack = 250;
    NSFileHandle *stdoutFileHandle = [notification object];
    NSData *stdoutData = [stdoutFileHandle availableData];
    NSString *stdoutString = [[NSString alloc] initWithData:stdoutData encoding:NSASCIIStringEncoding];
    [_stdoutLogOutput addObject:stdoutString];
    if ([_stdoutLogOutput count] > maxScrollBack) {
        [_stdoutLogOutput removeObjectAtIndex:0];
    }
    if (self.logsAreInView) {
        [[[_logView stdoutTextField] textStorage] appendAttributedString:[[NSAttributedString alloc]
                                                                      initWithString:stdoutString]];
        [[_logView stdoutTextField] scrollRangeToVisible:NSMakeRange([[[_logView stdoutTextField] string] length], 0)];
    }
    if (self.instance.isRunning) {
        [stdoutFileHandle waitForDataInBackgroundAndNotify];
    }
}

- (void)appendAndRotateStderrLogs:(NSNotification *)notification
{
    NSInteger maxScrollBack = 100;
    NSFileHandle *stderrFileHandle = [notification object];
    NSData *stderrData = [stderrFileHandle availableData];
    NSString *stderrString = [[NSString alloc] initWithData:stderrData encoding:NSASCIIStringEncoding];
    [_stderrLogOutput addObject:stderrString];
    if ([_stderrLogOutput count] > maxScrollBack) {
        [_stderrLogOutput removeObjectAtIndex:0];
    }
    if (self.logsAreInView) {
        [[[_logView stderrTextField] textStorage] appendAttributedString:[[NSAttributedString alloc]
                                                                      initWithString:stderrString]];
        [[_logView stderrTextField] scrollRangeToVisible:NSMakeRange([[[_logView stderrTextField] string] length], 0)];
    }
    if (self.instance.isRunning) {
        [stderrFileHandle waitForDataInBackgroundAndNotify];
    }
}

@end
