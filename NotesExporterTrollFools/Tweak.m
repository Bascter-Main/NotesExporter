#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static UIButton *batchButton;
static NSArray<NSManagedObjectID *> *currentSelectedIDs=@[];
static NSString *lastDiagnostic=@"";
static BOOL exporting=NO;
static NSMutableDictionary<NSString *, NSValue *> *menuOriginalIMPs;

static id Msg0(id obj, NSString *name){
    if(!obj)return nil; SEL s=NSSelectorFromString(name); if(![obj respondsToSelector:s])return nil;
    @try{return ((id(*)(id,SEL))objc_msgSend)(obj,s);}@catch(NSException *e){return nil;}
}
static id SafeKVC(id obj, NSArray<NSString *> *keys){
    for(NSString *k in keys){ @try{id v=[obj valueForKey:k]; if(v&&v!=NSNull.null)return v;}@catch(NSException *e){} }
    return nil;
}
static NSString *S(id v){
    if(!v||v==NSNull.null)return @"";
    if([v isKindOfClass:NSString.class])return v;
    if([v isKindOfClass:NSAttributedString.class])return [(NSAttributedString *)v string]?:@"";
    return [v description]?:@"";
}
static NSString *DateString(id v){
    if(![v isKindOfClass:NSDate.class])return S(v);
    static NSISO8601DateFormatter *f; static dispatch_once_t once; dispatch_once(&once,^{f=[NSISO8601DateFormatter new];});
    return [f stringFromDate:v]?:@"";
}

static UIWindow *KeyWindow(void){
    UIWindow *fallback=nil;
    for(UIScene *s in UIApplication.sharedApplication.connectedScenes){
        if(![s isKindOfClass:UIWindowScene.class])continue;
        for(UIWindow *w in ((UIWindowScene *)s).windows){
            if(s.activationState==UISceneActivationStateForegroundActive&&w.isKeyWindow)return w;
            if(!fallback&&!w.hidden)fallback=w;
        }
    }
    return fallback;
}
static UIViewController *Top(void){
    UIViewController *v=KeyWindow().rootViewController;
    while(v){
        if(v.presentedViewController){v=v.presentedViewController;continue;}
        if([v isKindOfClass:UINavigationController.class]){v=((UINavigationController *)v).visibleViewController;continue;}
        if([v isKindOfClass:UITabBarController.class]){v=((UITabBarController *)v).selectedViewController;continue;}
        break;
    }
    return v;
}
static UIViewController *LogicalTop(void){
    UIViewController *v=KeyWindow().rootViewController;
    while(v){
        if(v.presentedViewController){v=v.presentedViewController;continue;}
        if([v isKindOfClass:UINavigationController.class]){
            UINavigationController *nav=(UINavigationController *)v;
            v=nav.topViewController?:nav.visibleViewController;
            continue;
        }
        if([v isKindOfClass:UITabBarController.class]){v=((UITabBarController *)v).selectedViewController;continue;}
        break;
    }
    return v;
}
static BOOL NavigationTransitionActive(void){
    UIViewController *v=LogicalTop();
    UINavigationController *nav=v.navigationController;
    if(!nav){
        UIViewController *root=KeyWindow().rootViewController;
        if([root isKindOfClass:UINavigationController.class])nav=(UINavigationController *)root;
    }
    return nav.transitionCoordinator!=nil;
}
static BOOL ContainsEditableTextView(UIView *v){
    if(!v)return NO;
    if([v isKindOfClass:UITextView.class]&&((UITextView *)v).isEditable)return YES;
    for(UIView *s in v.subviews)if(ContainsEditableTextView(s))return YES;
    return NO;
}
static BOOL IsInsideNoteEditor(void){
    UIViewController *top=LogicalTop();
    if(!top)return NO;
    NSString *name=NSStringFromClass([top class]);
    if([name localizedCaseInsensitiveContainsString:@"NoteEditor"]||[name localizedCaseInsensitiveContainsString:@"EditorViewController"])return YES;
    return ContainsEditableTextView(top.view);
}

static id NoteContext(void){
    dlopen("/System/Library/PrivateFrameworks/NotesShared.framework/NotesShared",RTLD_LAZY|RTLD_GLOBAL);
    Class c=NSClassFromString(@"ICNoteContext");
    if(!c)return nil;
    return Msg0(c,@"sharedContext");
}
static NSManagedObjectContext *ManagedContext(void){
    id c=NoteContext(); id moc=Msg0(c,@"managedObjectContext");
    return [moc isKindOfClass:NSManagedObjectContext.class]?moc:nil;
}
static NSPersistentStoreCoordinator *Coordinator(void){
    id c=NoteContext(); id psc=Msg0(c,@"persistentStoreCoordinator");
    if([psc isKindOfClass:NSPersistentStoreCoordinator.class])return psc;
    return ManagedContext().persistentStoreCoordinator;
}

static NSManagedObjectID *ObjectIDFromIdentifier(id item){
    if([item isKindOfClass:NSManagedObjectID.class])return item;
    NSURL *url=nil;
    if([item isKindOfClass:NSURL.class])url=item;
    NSString *d=[item isKindOfClass:NSString.class]?item:[item description];
    if(!url&&d.length){
        NSRange r=[d rangeOfString:@"x-coredata://"];
        if(r.location!=NSNotFound){
            NSString *tail=[d substringFromIndex:r.location];
            NSCharacterSet *stop=[NSCharacterSet characterSetWithCharactersInString:@"> )]\n\t\r"];
            NSRange end=[tail rangeOfCharacterFromSet:stop];
            NSString *u=end.location==NSNotFound?tail:[tail substringToIndex:end.location];
            url=[NSURL URLWithString:u];
        }
    }
    NSPersistentStoreCoordinator *psc=Coordinator();
    return (url&&psc)?[psc managedObjectIDForURIRepresentation:url]:nil;
}
static BOOL IsNoteObjectID(NSManagedObjectID *oid){
    if(!oid)return NO;
    NSString *name=oid.entity.name?:@"";
    return [name isEqualToString:@"ICNote"];
}

static id ItemForIndexPath(id ds, NSIndexPath *p){
    SEL s=NSSelectorFromString(@"itemIdentifierForIndexPath:");
    if(ds&&[ds respondsToSelector:s]){
        @try{return ((id(*)(id,SEL,id))objc_msgSend)(ds,s,p);}@catch(NSException *e){return nil;}
    }
    return nil;
}
static void ScanSelected(UIView *v, NSMutableArray<NSManagedObjectID *> *ids, NSMutableArray<NSString *> *debug){
    if([v isKindOfClass:UICollectionView.class]){
        UICollectionView *cv=(UICollectionView *)v; id ds=cv.dataSource;
        for(NSIndexPath *p in cv.indexPathsForSelectedItems?:@[]){
            id item=ItemForIndexPath(ds,p); NSManagedObjectID *oid=ObjectIDFromIdentifier(item);
            if(IsNoteObjectID(oid)&&![ids containsObject:oid])[ids addObject:oid];
            else [debug addObject:[NSString stringWithFormat:@"CV %@ itemClass=%@ item=%@",p,item?NSStringFromClass([item class]):@"nil",item?:@"nil"]];
        }
    }else if([v isKindOfClass:UITableView.class]){
        UITableView *tv=(UITableView *)v; id ds=tv.dataSource;
        for(NSIndexPath *p in tv.indexPathsForSelectedRows?:@[]){
            id item=ItemForIndexPath(ds,p); NSManagedObjectID *oid=ObjectIDFromIdentifier(item);
            if(IsNoteObjectID(oid)&&![ids containsObject:oid])[ids addObject:oid];
            else [debug addObject:[NSString stringWithFormat:@"TV %@ itemClass=%@ item=%@",p,item?NSStringFromClass([item class]):@"nil",item?:@"nil"]];
        }
    }
    for(UIView *s in v.subviews)ScanSelected(s,ids,debug);
}
static NSArray<NSManagedObjectID *> *SelectedIDs(void){
    if(NavigationTransitionActive()||IsInsideNoteEditor())return @[];
    NSMutableArray *ids=[NSMutableArray array],*debug=[NSMutableArray array];
    UIViewController *v=Top(); if(v.view)ScanSelected(v.view,ids,debug);
    lastDiagnostic=debug.count?[debug componentsJoinedByString:@"\n"]:@"";
    return ids;
}

static NSString *BodyForNote(id note){
    id v=Msg0(note,@"noteAsPlainTextWithoutTitle");
    NSString *s=S(v); if(s.length)return s;
    v=Msg0(note,@"noteAsPlainText");
    s=S(v); if(s.length)return s;
    v=Msg0(note,@"attributedString");
    s=S(v); if(s.length)return s;
    id storage=Msg0(note,@"textStorage");
    v=Msg0(storage,@"string");
    s=S(v); if(s.length)return s;
    return @"";
}

static NSDictionary *SerializeNote(NSManagedObject *n){
    id folder=SafeKVC(n,@[@"folder",@"noteContainer"]);
    return @{
        @"title":S(SafeKVC(n,@[@"title",@"title1",@"displayTitle"])),
        @"body":BodyForNote(n),
        @"created":DateString(SafeKVC(n,@[@"creationDate",@"creationDate1"])),
        @"modified":DateString(SafeKVC(n,@[@"modificationDate",@"modificationDate1"])),
        @"identifier":S(SafeKVC(n,@[@"identifier",@"noteIdentifier"])),
        @"objectID":n.objectID.URIRepresentation.absoluteString?:@"",
        @"folder":S(SafeKVC(folder,@[@"title",@"name"]))
    };
}

static void Alert(NSString *title,NSString *message){
    dispatch_async(dispatch_get_main_queue(),^{
        UIViewController *v=Top(); if(!v)return;
        UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [v presentViewController:a animated:YES completion:nil];
    });
}

static void ExportObjectIDs(NSArray<NSManagedObjectID *> *ids, BOOL single){
    if(exporting)return;
    if(!ids.count){Alert(@"无法导出",lastDiagnostic.length?lastDiagnostic:@"没有取得备忘录对象 ID。");return;}
    NSManagedObjectContext *moc=ManagedContext();
    if(!moc){Alert(@"无法导出",@"没有取得 Notes 的 managedObjectContext。");return;}
    exporting=YES;
    [moc performBlock:^{
        NSMutableArray *rows=[NSMutableArray array]; NSMutableArray *errors=[NSMutableArray array];
        for(NSManagedObjectID *oid in ids){
            NSError *e=nil; NSManagedObject *obj=[moc existingObjectWithID:oid error:&e];
            if(obj&&!e)[rows addObject:SerializeNote(obj)];
            else [errors addObject:e.localizedDescription?:oid.URIRepresentation.absoluteString?:@"unknown"];
        }
        NSDictionary *root=@{@"format":@"Apple Notes Export",@"version":@9,@"count":@(rows.count),@"notes":rows};
        NSError *je=nil; NSData *data=[NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:&je];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
            NSDateFormatter *f=[NSDateFormatter new];f.dateFormat=@"yyyyMMdd-HHmmss";
            NSString *name=[NSString stringWithFormat:single?@"AppleNote-%@.json":@"AppleNotes-Selected-%@.json",[f stringFromDate:NSDate.date]];
            NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:name]; NSError *we=nil;
            BOOL ok=data&&[data writeToFile:path options:NSDataWritingAtomic error:&we];
            dispatch_async(dispatch_get_main_queue(),^{
                exporting=NO;
                if(!ok){Alert(@"导出失败",we.localizedDescription?:je.localizedDescription?:@"无法写入文件");return;}
                if(!rows.count){Alert(@"导出失败",errors.count?[errors componentsJoinedByString:@"\n"]:@"没有解析到 ICNote 对象。");return;}
                UIViewController *v=Top(); UIActivityViewController *a=[[UIActivityViewController alloc]initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
                if(a.popoverPresentationController)a.popoverPresentationController.sourceView=v.view;
                [v presentViewController:a animated:YES completion:nil];
            });
        });
    }];
}

@interface NEHandler:NSObject
+(instancetype)shared;-(void)batch:(id)sender;
@end
@implementation NEHandler
+(instancetype)shared{static id x;static dispatch_once_t once;dispatch_once(&once,^{x=[self new];});return x;}
-(void)batch:(id)sender{ExportObjectIDs(SelectedIDs(),NO);}
@end

static IMP OriginalMenuIMPForClass(Class cls){
    Class c=cls;
    while(c){
        NSValue *v=menuOriginalIMPs[NSStringFromClass(c)];
        if(v)return [v pointerValue];
        c=class_getSuperclass(c);
    }
    return NULL;
}

static UIContextMenuConfiguration *NEContextMenu(id self, SEL _cmd, UICollectionView *collectionView, NSIndexPath *indexPath, CGPoint point){
    IMP imp=OriginalMenuIMPForClass([self class]);
    if(!imp)return nil;
    UIContextMenuConfiguration *base=((UIContextMenuConfiguration *(*)(id,SEL,UICollectionView *,NSIndexPath *,CGPoint))imp)(self,_cmd,collectionView,indexPath,point);
    if(!base)return nil;
    if(NavigationTransitionActive()||IsInsideNoteEditor())return base;

    id item=ItemForIndexPath(collectionView.dataSource,indexPath);
    NSManagedObjectID *oid=ObjectIDFromIdentifier(item);
    if(!IsNoteObjectID(oid))return base;

    UIContextMenuContentPreviewProvider preview=(UIContextMenuContentPreviewProvider)Msg0(base,@"previewProvider");
    UIContextMenuActionProvider originalProvider=(UIContextMenuActionProvider)Msg0(base,@"actionProvider");
    id<NSCopying> identifier=base.identifier;
    UIContextMenuActionProvider wrapped=^UIMenu *(NSArray<UIMenuElement *> *suggested){
        UIMenu *menu=originalProvider?originalProvider(suggested):nil;
        NSMutableArray<UIMenuElement *> *children=[NSMutableArray array];
        if(menu.children.count)[children addObjectsFromArray:menu.children];
        else if(suggested.count)[children addObjectsFromArray:suggested];
        UIAction *exportAction=[UIAction actionWithTitle:@"导出备忘录" image:[UIImage systemImageNamed:@"square.and.arrow.up"] identifier:nil handler:^(__kindof UIAction *action){
            ExportObjectIDs(@[oid],YES);
        }];
        [children addObject:exportAction];
        return [UIMenu menuWithTitle:menu.title?:@"" image:menu.image identifier:menu.identifier options:menu.options children:children];
    };
    return [UIContextMenuConfiguration configurationWithIdentifier:identifier previewProvider:preview actionProvider:wrapped];
}

static void InstallMenuHookForDelegate(id delegate){
    if(!delegate)return;
    Class cls=[delegate class];
    NSString *key=NSStringFromClass(cls);
    if(menuOriginalIMPs[key])return;
    SEL sel=NSSelectorFromString(@"collectionView:contextMenuConfigurationForItemAtIndexPath:point:");
    Method method=class_getInstanceMethod(cls,sel);
    if(!method)return;
    IMP original=method_getImplementation(method);
    const char *types=method_getTypeEncoding(method);
    menuOriginalIMPs[key]=[NSValue valueWithPointer:original];
    if(!class_addMethod(cls,sel,(IMP)NEContextMenu,types)){
        Method own=class_getInstanceMethod(cls,sel);
        method_setImplementation(own,(IMP)NEContextMenu);
    }
}

static void InstallMenuHooksInView(UIView *v){
    if([v isKindOfClass:UICollectionView.class]){
        UICollectionView *cv=(UICollectionView *)v;
        InstallMenuHookForDelegate(cv.delegate);
    }
    for(UIView *s in v.subviews)InstallMenuHooksInView(s);
}

static void UpdateButtonAndHooks(void){
    UIWindow *w=KeyWindow(); if(!w)return;

    if(NavigationTransitionActive()){
        currentSelectedIDs=@[];
        if(batchButton)batchButton.hidden=YES;
        return;
    }

    BOOL inEditor=IsInsideNoteEditor();
    UIViewController *top=Top();
    if(top.view&&!inEditor)InstallMenuHooksInView(top.view);
    currentSelectedIDs=inEditor?@[]:SelectedIDs();

    // Batch export is specifically for multiple notes. A normal tap briefly selects
    // one list item while pushing the editor; never treat that as batch selection.
    if(currentSelectedIDs.count>=2){
        if(!batchButton){
            batchButton=[UIButton buttonWithType:UIButtonTypeSystem]; batchButton.backgroundColor=[UIColor systemYellowColor];
            [batchButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal]; batchButton.titleLabel.font=[UIFont boldSystemFontOfSize:16];
            batchButton.layer.cornerRadius=22; batchButton.layer.shadowOpacity=.22; batchButton.layer.shadowRadius=4;
            [batchButton addTarget:NEHandler.shared action:@selector(batch:) forControlEvents:UIControlEventTouchUpInside];
        }
        [batchButton setTitle:[NSString stringWithFormat:@"导出所选 (%lu)",(unsigned long)currentSelectedIDs.count] forState:UIControlStateNormal];
        if(batchButton.superview!=w){[batchButton removeFromSuperview];[w addSubview:batchButton];}
        CGFloat width=160,height=44;batchButton.frame=CGRectMake((w.bounds.size.width-width)/2.0,w.bounds.size.height-w.safeAreaInsets.bottom-92,width,height);
        batchButton.hidden=NO;[w bringSubviewToFront:batchButton];
    }else if(batchButton){
        batchButton.hidden=YES;
    }
}

__attribute__((constructor))static void Init(void){
    @autoreleasepool{
        if(![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.mobilenotes"])return;
        menuOriginalIMPs=[NSMutableDictionary dictionary];
        dlopen("/System/Library/PrivateFrameworks/NotesShared.framework/NotesShared",RTLD_LAZY|RTLD_GLOBAL);
        dispatch_async(dispatch_get_main_queue(),^{[NSTimer scheduledTimerWithTimeInterval:.35 repeats:YES block:^(__unused NSTimer *t){UpdateButtonAndHooks();}];});
    }
}
