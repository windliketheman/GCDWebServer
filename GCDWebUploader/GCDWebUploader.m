/*
 Copyright (c) 2012-2019, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if !__has_feature(objc_arc)
#error GCDWebUploader requires ARC
#endif

#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <SystemConfiguration/SystemConfiguration.h>
#endif

#import "GCDWebUploader.h"
#import "GCDWebServerFunctions.h"

#import "GCDWebServerDataRequest.h"
#import "GCDWebServerMultiPartFormRequest.h"
#import "GCDWebServerURLEncodedFormRequest.h"

#import "GCDWebServerDataResponse.h"
#import "GCDWebServerErrorResponse.h"
#import "GCDWebServerFileResponse.h"

NS_ASSUME_NONNULL_BEGIN

@interface GCDWebUploader (Methods)
- (nullable GCDWebServerResponse*)listDirectory:(GCDWebServerRequest*)request;
- (nullable GCDWebServerResponse*)downloadFile:(GCDWebServerRequest*)request;
- (nullable GCDWebServerResponse*)uploadFile:(GCDWebServerMultiPartFormRequest*)request;
- (nullable GCDWebServerResponse*)moveItem:(GCDWebServerURLEncodedFormRequest*)request;
- (nullable GCDWebServerResponse*)deleteItem:(GCDWebServerURLEncodedFormRequest*)request;
- (nullable GCDWebServerResponse*)createDirectory:(GCDWebServerURLEncodedFormRequest*)request;
- (nullable GCDWebServerResponse*)createUploadDirectory:(GCDWebServerURLEncodedFormRequest*)request;
@end

NS_ASSUME_NONNULL_END

@implementation GCDWebUploader

@dynamic delegate;

- (instancetype)initWithUploadDirectory:(NSString*)path {
  if ((self = [super init])) {
    NSString* bundlePath = [[NSBundle bundleForClass:[GCDWebUploader class]] pathForResource:@"GCDWebUploader" ofType:@"bundle"];
    if (bundlePath == nil) {
      return nil;
    }
    NSBundle* siteBundle = [NSBundle bundleWithPath:bundlePath];
    if (siteBundle == nil) {
      return nil;
    }
    _uploadDirectory = [path copy];
    GCDWebUploader* __unsafe_unretained server = self;

    // Resource files
    [self addGETHandlerForBasePath:@"/" directoryPath:(NSString*)[siteBundle resourcePath] indexFilename:nil cacheAge:3600 allowRangeRequests:NO];

    // Web page
    [self addHandlerForMethod:@"GET"
                         path:@"/"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {

#if TARGET_OS_IPHONE
                   NSString* device = [[UIDevice currentDevice] name];
#else
          NSString* device = CFBridgingRelease(SCDynamicStoreCopyComputerName(NULL, NULL));
#endif
                   NSString* title = server.title;
                   if (title == nil) {
                     title = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
                     if (title == nil) {
                       title = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
                     }
#if !TARGET_OS_IPHONE
                     if (title == nil) {
                       title = [[NSProcessInfo processInfo] processName];
                     }
#endif
                   }
                   
                   NSString *key = @"";

                   NSString* header = server.header;
                   if (header == nil) {
                     header = title;
                   }
                   NSString* prologue = server.prologue; key = @"PROLOGUE";
                   if (prologue == nil) {
                     prologue = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString* epilogue = server.epilogue; key = @"EPILOGUE";
                   if (epilogue == nil) {
                     epilogue = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString* footer = server.footer; key = @"FOOTER_FORMAT";
                   if (footer == nil) {
                     NSString* name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
                     if (name == nil) {
                       name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
                     }
                     NSString* version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
#if !TARGET_OS_IPHONE
                     if (!name && !version) {
                       name = @"OS X";
                       version = [[NSProcessInfo processInfo] operatingSystemVersionString];
                     }
#endif
                     footer = [NSString stringWithFormat:[siteBundle localizedStringForKey:key value:@"" table:nil], name, version];
                   }
                   NSString *upload = nil; key = @"UPLOAD";
                   if ([siteBundle localizedStringForKey:key value:@"" table:nil]) {
                     upload = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString *createFolder = nil; key = @"CREATE_FOLDER";
                   if ([siteBundle localizedStringForKey:key value:@"" table:nil]) {
                     createFolder = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString *refresh = nil; key = @"REFRESH";
                   if ([siteBundle localizedStringForKey:key value:@"" table:nil]) {
                     refresh = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString *cancel = nil; key = @"CANCEL";
                   if ([siteBundle localizedStringForKey:key value:@"" table:nil]) {
                     cancel = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString *createFolderDescription = nil; key = @"PLEASE_ENTER_THE_NEME_OF_THE_FOLDER_TO_BE_CREATED";
                   if ([siteBundle localizedStringForKey:key value:@"" table:nil]) {
                     createFolderDescription = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString *untitledFolder = nil; key = @"UNTITLED_FOLDER";
                   if ([siteBundle localizedStringForKey:key value:@"" table:nil]) {
                     untitledFolder = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString *create = nil; key = @"CREATE";
                   if ([siteBundle localizedStringForKey:key value:@"" table:nil]) {
                     create = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString *moveItem = nil; key = @"MOVE_ITEM";
                   if ([siteBundle localizedStringForKey:key value:@"" table:nil]) {
                     moveItem = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString *moveItemDescription = nil; key = @"PLEASE_ENTER_THE_NEW_LOCATION_FOR_THIS_ITEM";
                   if ([siteBundle localizedStringForKey:key value:@"" table:nil]) {
                     moveItemDescription = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   NSString *move = nil; key = @"MOVE";
                   if ([siteBundle localizedStringForKey:key value:@"" table:nil]) {
                     move = [siteBundle localizedStringForKey:key value:@"" table:nil];
                   }
                   
                   return [GCDWebServerDataResponse responseWithHTMLTemplate:(NSString*)[siteBundle pathForResource:@"index" ofType:@"html"]
                                                                   variables:@{
                                                                     @"device" : device,
                                                                     @"title" : title,
                                                                     @"header" : header,
                                                                     @"prologue" : prologue,
                                                                     @"upload": upload,
                                                                     @"create_folder": createFolder,
                                                                     @"refresh": refresh,
                                                                     @"cancel": cancel,
                                                                     @"create_folder_description": createFolderDescription,
                                                                     // @"untitled_folder": untitledFolder,
                                                                     @"create": create,
                                                                     @"move_item": moveItem,
                                                                     @"move_item_description": moveItemDescription,
                                                                     @"move": move,
                                                                     @"epilogue" : epilogue,
                                                                     @"footer" : footer
                                                                   }];
                 }];

    // File listing
    [self addHandlerForMethod:@"GET"
                         path:@"/list"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                   return [server listDirectory:request];
                 }];

    // File download
    [self addHandlerForMethod:@"GET"
                         path:@"/download"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                   return [server downloadFile:request];
                 }];

    // File upload
    [self addHandlerForMethod:@"POST"
                         path:@"/upload"
                 requestClass:[GCDWebServerMultiPartFormRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                   return [server uploadFile:(GCDWebServerMultiPartFormRequest*)request];
                 }];

    // File and folder moving
    [self addHandlerForMethod:@"POST"
                         path:@"/move"
                 requestClass:[GCDWebServerURLEncodedFormRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                   return [server moveItem:(GCDWebServerURLEncodedFormRequest*)request];
                 }];

    // File and folder deletion
    [self addHandlerForMethod:@"POST"
                         path:@"/delete"
                 requestClass:[GCDWebServerURLEncodedFormRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                   return [server deleteItem:(GCDWebServerURLEncodedFormRequest*)request];
                 }];

    // Directory creation
    [self addHandlerForMethod:@"POST"
                         path:@"/create"
                 requestClass:[GCDWebServerURLEncodedFormRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                   return [server createDirectory:(GCDWebServerURLEncodedFormRequest*)request];
                 }];

    // Directory creation for folder uploads
    [self addHandlerForMethod:@"POST"
                         path:@"/create-upload"
                 requestClass:[GCDWebServerURLEncodedFormRequest class]
                 processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
                   return [server createUploadDirectory:(GCDWebServerURLEncodedFormRequest*)request];
                 }];
  }
  return self;
}

@end

@implementation GCDWebUploader (Methods)

- (BOOL)_checkFileExtension:(NSString*)fileName {
  if (_allowedFileExtensions && ![_allowedFileExtensions containsObject:[[fileName pathExtension] lowercaseString]]) {
    return NO;
  }
  return YES;
}

- (NSString*)_uniquePathForPath:(NSString*)path {
  if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
    NSString* directory = [path stringByDeletingLastPathComponent];
    NSString* file = [path lastPathComponent];
    NSString* base = [file stringByDeletingPathExtension];
    NSString* extension = [file pathExtension];
    int retries = 0;
    do {
      if (extension.length) {
        path = [directory stringByAppendingPathComponent:(NSString*)[[base stringByAppendingFormat:@" (%i)", ++retries] stringByAppendingPathExtension:extension]];
      } else {
        path = [directory stringByAppendingPathComponent:[base stringByAppendingFormat:@" (%i)", ++retries]];
      }
    } while ([[NSFileManager defaultManager] fileExistsAtPath:path]);
  }
  return path;
}

- (NSString*)_uniqueFolderNameForBasePath:(NSString*)basePath name:(NSString*)name {
  NSString* candidate = name;
  NSString* candidatePath = [basePath stringByAppendingPathComponent:candidate];
  int retries = 0;
  while ([[NSFileManager defaultManager] fileExistsAtPath:candidatePath]) {
    candidate = [NSString stringWithFormat:@"%@-%i", name, ++retries];
    candidatePath = [basePath stringByAppendingPathComponent:candidate];
  }
  return candidate;
}

- (NSString*)_mappedRootFolderForBasePath:(NSString*)basePath rootFolder:(NSString*)rootFolder uploadId:(NSString*)uploadId {
  static NSMutableDictionary<NSString*, NSMutableDictionary<NSString*, NSString*>*>* uploadFolderMap = nil;
  static dispatch_queue_t uploadFolderQueue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    uploadFolderMap = [[NSMutableDictionary alloc] init];
    uploadFolderQueue = dispatch_queue_create("com.orange.webuploader.foldermap", DISPATCH_QUEUE_SERIAL);
  });

  __block NSString* mappedRoot = nil;
  dispatch_sync(uploadFolderQueue, ^{
    NSString* mapKey = [NSString stringWithFormat:@"%@|%@", basePath, rootFolder];
    NSMutableDictionary<NSString*, NSString*>* rootMap = uploadId.length ? uploadFolderMap[uploadId] : nil;
    if (uploadId.length && !rootMap) {
      rootMap = [[NSMutableDictionary alloc] init];
      uploadFolderMap[uploadId] = rootMap;
    }

    if (uploadId.length) {
      mappedRoot = rootMap[mapKey];
      if (!mappedRoot) {
        mappedRoot = [self _uniqueFolderNameForBasePath:basePath name:rootFolder];
        rootMap[mapKey] = mappedRoot;
      }
    } else {
      mappedRoot = [self _uniqueFolderNameForBasePath:basePath name:rootFolder];
    }
  });

  return mappedRoot ?: rootFolder;
}

- (NSString*)_mappedRelativePathForBaseRelativePath:(NSString*)baseRelativePath relativePath:(NSString*)relativePath uploadId:(NSString*)uploadId {
  if (!relativePath.length) {
    return GCDWebServerNormalizePath(baseRelativePath);
  }

  NSString* normalizedRelativePath = GCDWebServerNormalizePath(relativePath);
  NSArray* components = [normalizedRelativePath pathComponents];
  if (components.count == 0) {
    return GCDWebServerNormalizePath(baseRelativePath);
  }

  NSString* normalizedBase = GCDWebServerNormalizePath(baseRelativePath);
  NSString* basePath = [_uploadDirectory stringByAppendingPathComponent:normalizedBase];
  NSString* rootFolder = components.firstObject;
  NSString* mappedRoot = [self _mappedRootFolderForBasePath:basePath rootFolder:rootFolder uploadId:uploadId];

  NSMutableArray* mappedComponents = [NSMutableArray arrayWithObject:mappedRoot];
  if (components.count > 1) {
    [mappedComponents addObjectsFromArray:[components subarrayWithRange:NSMakeRange(1, components.count - 1)]];
  }

  NSString* mappedPath = [NSString pathWithComponents:mappedComponents];
  return [normalizedBase stringByAppendingPathComponent:mappedPath];
}

- (GCDWebServerResponse*)listDirectory:(GCDWebServerRequest*)request {
  NSString* relativePath = [[request query] objectForKey:@"path"];
  NSString* absolutePath = [_uploadDirectory stringByAppendingPathComponent:GCDWebServerNormalizePath(relativePath)];
  BOOL isDirectory = NO;
  if (!absolutePath || ![[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", relativePath];
  }
  if (!isDirectory) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest message:@"\"%@\" is not a directory", relativePath];
  }

  NSString* directoryName = [absolutePath lastPathComponent];
  if (!_allowHiddenItems && [directoryName hasPrefix:@"."]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Listing directory name \"%@\" is not allowed", directoryName];
  }

  NSError* error = nil;
  NSArray* contents = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:absolutePath error:&error] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
  if (contents == nil) {
    return [GCDWebServerErrorResponse responseWithServerError:kGCDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed listing directory \"%@\"", relativePath];
  }

  NSMutableArray* array = [NSMutableArray array];
  for (NSString* item in [contents sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
    if (_allowHiddenItems || ![item hasPrefix:@"."]) {
      NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[absolutePath stringByAppendingPathComponent:item] error:NULL];
      NSString* type = [attributes objectForKey:NSFileType];
      if ([type isEqualToString:NSFileTypeRegular] && [self _checkFileExtension:item]) {
        [array addObject:@{
          @"path" : [relativePath stringByAppendingPathComponent:item],
          @"name" : item,
          @"size" : (NSNumber*)[attributes objectForKey:NSFileSize]
        }];
      } else if ([type isEqualToString:NSFileTypeDirectory]) {
        [array addObject:@{
          @"path" : [[relativePath stringByAppendingPathComponent:item] stringByAppendingString:@"/"],
          @"name" : item
        }];
      }
    }
  }
  return [GCDWebServerDataResponse responseWithJSONObject:array];
}

- (GCDWebServerResponse*)downloadFile:(GCDWebServerRequest*)request {
  NSString* relativePath = [[request query] objectForKey:@"path"];
  NSString* absolutePath = [_uploadDirectory stringByAppendingPathComponent:GCDWebServerNormalizePath(relativePath)];
  BOOL isDirectory = NO;
  if (![[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", relativePath];
  }
  if (isDirectory) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_BadRequest message:@"\"%@\" is a directory", relativePath];
  }

  NSString* fileName = [absolutePath lastPathComponent];
  if (([fileName hasPrefix:@"."] && !_allowHiddenItems) || ![self _checkFileExtension:fileName]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Downlading file name \"%@\" is not allowed", fileName];
  }

  if ([self.delegate respondsToSelector:@selector(webUploader:didDownloadFileAtPath:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didDownloadFileAtPath:absolutePath];
    });
  }
  return [GCDWebServerFileResponse responseWithFile:absolutePath isAttachment:YES];
}

- (GCDWebServerResponse*)uploadFile:(GCDWebServerMultiPartFormRequest*)request {
  NSRange range = [[request.headers objectForKey:@"Accept"] rangeOfString:@"application/json" options:NSCaseInsensitiveSearch];
  NSString* contentType = (range.location != NSNotFound ? @"application/json" : @"text/plain; charset=utf-8");  // Required when using iFrame transport (see https://github.com/blueimp/jQuery-File-Upload/wiki/Setup)

  GCDWebServerMultiPartFile* file = [request firstFileForControlName:@"files[]"];
  if ((!_allowHiddenItems && [file.fileName hasPrefix:@"."]) || ![self _checkFileExtension:file.fileName]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Uploaded file name \"%@\" is not allowed", file.fileName];
  }
  NSString* relativePath = [[request firstArgumentForControlName:@"path"] string];
  NSString* relativePathFromClient = [[request firstArgumentForControlName:@"relativePath"] string];
  NSString* uploadId = [[request firstArgumentForControlName:@"uploadId"] string];
  if ([relativePathFromClient isEqualToString:@"(null)"] || [relativePathFromClient isEqualToString:@"null"]) {
    relativePathFromClient = nil;
  }
  NSString* targetFileName = file.fileName;
  NSString* targetRelativeDirectory = GCDWebServerNormalizePath(relativePath);

  if (relativePathFromClient.length) {
    NSString* mappedRelativePath = [self _mappedRelativePathForBaseRelativePath:relativePath relativePath:relativePathFromClient uploadId:uploadId];
    targetFileName = [mappedRelativePath lastPathComponent];
    targetRelativeDirectory = [mappedRelativePath stringByDeletingLastPathComponent];
  }

  NSString* absoluteDirectory = [_uploadDirectory stringByAppendingPathComponent:targetRelativeDirectory];
  if (![[NSFileManager defaultManager] fileExistsAtPath:absoluteDirectory]) {
    [[NSFileManager defaultManager] createDirectoryAtPath:absoluteDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
  }
  NSString* absolutePath = [self _uniquePathForPath:[absoluteDirectory stringByAppendingPathComponent:targetFileName]];

  if (![self shouldUploadFileAtPath:absolutePath withTemporaryFile:file.temporaryPath]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Uploading file \"%@\" to \"%@\" is not permitted", targetFileName, targetRelativeDirectory];
  }

  NSError* error = nil;
  if (!file.temporaryPath || ![[NSFileManager defaultManager] moveItemAtPath:file.temporaryPath toPath:absolutePath error:&error]) {
    return [GCDWebServerErrorResponse responseWithServerError:kGCDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed moving uploaded file to \"%@\"", targetRelativeDirectory];
  }

  if ([self.delegate respondsToSelector:@selector(webUploader:didUploadFileAtPath:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didUploadFileAtPath:absolutePath];
    });
  }
  return [GCDWebServerDataResponse responseWithJSONObject:@{} contentType:contentType];
}

- (GCDWebServerResponse*)moveItem:(GCDWebServerURLEncodedFormRequest*)request {
  NSString* oldRelativePath = [request.arguments objectForKey:@"oldPath"];
  NSString* oldAbsolutePath = [_uploadDirectory stringByAppendingPathComponent:GCDWebServerNormalizePath(oldRelativePath)];
  BOOL isDirectory = NO;
  if (![[NSFileManager defaultManager] fileExistsAtPath:oldAbsolutePath isDirectory:&isDirectory]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", oldRelativePath];
  }

  NSString* oldItemName = [oldAbsolutePath lastPathComponent];
  if ((!_allowHiddenItems && [oldItemName hasPrefix:@"."]) || (!isDirectory && ![self _checkFileExtension:oldItemName])) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Moving from item name \"%@\" is not allowed", oldItemName];
  }

  NSString* newRelativePath = [request.arguments objectForKey:@"newPath"];
  NSString* newAbsolutePath = [self _uniquePathForPath:[_uploadDirectory stringByAppendingPathComponent:GCDWebServerNormalizePath(newRelativePath)]];

  NSString* newItemName = [newAbsolutePath lastPathComponent];
  if ((!_allowHiddenItems && [newItemName hasPrefix:@"."]) || (!isDirectory && ![self _checkFileExtension:newItemName])) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Moving to item name \"%@\" is not allowed", newItemName];
  }

  if (![self shouldMoveItemFromPath:oldAbsolutePath toPath:newAbsolutePath]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Moving \"%@\" to \"%@\" is not permitted", oldRelativePath, newRelativePath];
  }

  NSError* error = nil;
  if (![[NSFileManager defaultManager] moveItemAtPath:oldAbsolutePath toPath:newAbsolutePath error:&error]) {
    return [GCDWebServerErrorResponse responseWithServerError:kGCDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed moving \"%@\" to \"%@\"", oldRelativePath, newRelativePath];
  }

  if ([self.delegate respondsToSelector:@selector(webUploader:didMoveItemFromPath:toPath:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didMoveItemFromPath:oldAbsolutePath toPath:newAbsolutePath];
    });
  }
  return [GCDWebServerDataResponse responseWithJSONObject:@{}];
}

- (GCDWebServerResponse*)deleteItem:(GCDWebServerURLEncodedFormRequest*)request {
  NSString* relativePath = [request.arguments objectForKey:@"path"];
  NSString* absolutePath = [_uploadDirectory stringByAppendingPathComponent:GCDWebServerNormalizePath(relativePath)];
  BOOL isDirectory = NO;
  if (![[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_NotFound message:@"\"%@\" does not exist", relativePath];
  }

  NSString* itemName = [absolutePath lastPathComponent];
  if (([itemName hasPrefix:@"."] && !_allowHiddenItems) || (!isDirectory && ![self _checkFileExtension:itemName])) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Deleting item name \"%@\" is not allowed", itemName];
  }

  if (![self shouldDeleteItemAtPath:absolutePath]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Deleting \"%@\" is not permitted", relativePath];
  }

  NSError* error = nil;
  if (![[NSFileManager defaultManager] removeItemAtPath:absolutePath error:&error]) {
    return [GCDWebServerErrorResponse responseWithServerError:kGCDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed deleting \"%@\"", relativePath];
  }

  if ([self.delegate respondsToSelector:@selector(webUploader:didDeleteItemAtPath:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didDeleteItemAtPath:absolutePath];
    });
  }
  return [GCDWebServerDataResponse responseWithJSONObject:@{}];
}

- (GCDWebServerResponse*)createDirectory:(GCDWebServerURLEncodedFormRequest*)request {
  NSString* relativePath = [request.arguments objectForKey:@"path"];
  NSString* absolutePath = [self _uniquePathForPath:[_uploadDirectory stringByAppendingPathComponent:GCDWebServerNormalizePath(relativePath)]];

  NSString* directoryName = [absolutePath lastPathComponent];
  if (!_allowHiddenItems && [directoryName hasPrefix:@"."]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Creating directory name \"%@\" is not allowed", directoryName];
  }

  if (![self shouldCreateDirectoryAtPath:absolutePath]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Creating directory \"%@\" is not permitted", relativePath];
  }

  NSError* error = nil;
  if (![[NSFileManager defaultManager] createDirectoryAtPath:absolutePath withIntermediateDirectories:NO attributes:nil error:&error]) {
    return [GCDWebServerErrorResponse responseWithServerError:kGCDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed creating directory \"%@\"", relativePath];
  }

  if ([self.delegate respondsToSelector:@selector(webUploader:didCreateDirectoryAtPath:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didCreateDirectoryAtPath:absolutePath];
    });
  }
  return [GCDWebServerDataResponse responseWithJSONObject:@{}];
}

- (GCDWebServerResponse*)createUploadDirectory:(GCDWebServerURLEncodedFormRequest*)request {
  NSString* baseRelativePath = [request.arguments objectForKey:@"path"];
  NSString* relativePathFromClient = [request.arguments objectForKey:@"relativePath"];
  NSString* uploadId = [request.arguments objectForKey:@"uploadId"];

  if (!relativePathFromClient.length) {
    return [GCDWebServerDataResponse responseWithJSONObject:@{}];
  }

  NSString* mappedRelativePath = [self _mappedRelativePathForBaseRelativePath:baseRelativePath relativePath:relativePathFromClient uploadId:uploadId];
  NSString* absolutePath = [_uploadDirectory stringByAppendingPathComponent:mappedRelativePath];
  NSString* directoryName = [absolutePath lastPathComponent];
  if (!_allowHiddenItems && [directoryName hasPrefix:@"."]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Creating directory name \"%@\" is not allowed", directoryName];
  }

  if (![self shouldCreateDirectoryAtPath:absolutePath]) {
    return [GCDWebServerErrorResponse responseWithClientError:kGCDWebServerHTTPStatusCode_Forbidden message:@"Creating directory \"%@\" is not permitted", mappedRelativePath];
  }

  NSError* error = nil;
  if (![[NSFileManager defaultManager] createDirectoryAtPath:absolutePath withIntermediateDirectories:YES attributes:nil error:&error]) {
    return [GCDWebServerErrorResponse responseWithServerError:kGCDWebServerHTTPStatusCode_InternalServerError underlyingError:error message:@"Failed creating directory \"%@\"", mappedRelativePath];
  }

  if ([self.delegate respondsToSelector:@selector(webUploader:didCreateDirectoryAtPath:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate webUploader:self didCreateDirectoryAtPath:absolutePath];
    });
  }
  return [GCDWebServerDataResponse responseWithJSONObject:@{ @"path": mappedRelativePath ?: @"" }];
}

@end

@implementation GCDWebUploader (Subclassing)

- (BOOL)shouldUploadFileAtPath:(NSString*)path withTemporaryFile:(NSString*)tempPath {
  return YES;
}

- (BOOL)shouldMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
  return YES;
}

- (BOOL)shouldDeleteItemAtPath:(NSString*)path {
  return YES;
}

- (BOOL)shouldCreateDirectoryAtPath:(NSString*)path {
  return YES;
}

@end
