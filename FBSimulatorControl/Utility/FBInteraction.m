/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBInteraction.h"

#import "FBInteraction+Private.h"
#import "FBSimulatorError.h"

@implementation FBInteraction

- (instancetype)init
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _interactions = [NSMutableArray array];
  return self;
}

+ (id<FBInteraction>)chainInteractions:(NSArray *)interactions
{
  return [FBInteraction_Block interactionWithBlock:^ BOOL (NSError **error) {
    for (id<FBInteraction> interaction in interactions) {
      NSError *innerError = nil;
      if (![interaction performInteractionWithError:&innerError]) {
        return [FBSimulatorError failBoolWithError:innerError errorOut:error];
      }
    }
    return YES;
  }];
}

- (instancetype)interact:(BOOL (^)(NSError **error))block
{
  NSParameterAssert(block);
  return [self addInteraction:[FBInteraction_Block interactionWithBlock:block]];
}

- (instancetype)addInteraction:(id<FBInteraction>)interaction
{
  [self.interactions addObject:interaction];
  return self;
}

- (instancetype)retry:(NSUInteger)retries
{
  NSParameterAssert(self.interactions.count > 0);
  NSParameterAssert(retries > 1);

  NSUInteger interactionIndex = self.interactions.count - 1;
  id<FBInteraction> interaction = self.interactions[interactionIndex];

  id<FBInteraction> retryInteraction = [FBInteraction_Block interactionWithBlock:^ BOOL (NSError **error) {
    NSError *innerError = nil;
    for (NSUInteger index = 0; index < retries; index++) {
      if ([interaction performInteractionWithError:&innerError]) {
        return YES;
      }
    }
    return [[[FBSimulatorError describeFormat:@"Failed interaction after %ld retries", retries] causedBy:innerError] failBool:error];
  }];

  [self.interactions replaceObjectAtIndex:interactionIndex withObject:retryInteraction];
  return self;
}

- (id<FBInteraction>)build
{
  return [FBInteraction chainInteractions:[self.interactions copy]];
}

- (BOOL)performInteractionWithError:(NSError **)error
{
  return [[self build] performInteractionWithError:error];
}

@end

@implementation FBInteraction_Block

+ (id<FBInteraction>)interactionWithBlock:( BOOL(^)(NSError **error) )block
{
  FBInteraction_Block *interaction = [self new];
  interaction.block = block;
  return interaction;
}

- (BOOL)performInteractionWithError:(NSError **)error
{
  NSError *innerError = nil;
  BOOL success = self.block(&innerError);
  if (!success && error) {
    *error = innerError;
  }
  return success;
}

@end
