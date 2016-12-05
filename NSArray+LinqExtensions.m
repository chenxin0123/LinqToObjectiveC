//
//  NSArray+LinqExtensions.m
//  LinqToObjectiveC
//
//  Created by Colin Eberhardt on 02/02/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import "NSArray+LinqExtensions.h"

@implementation NSArray (QueryExtension)

/// 返回符合predicate的所有项 filter
- (NSArray *)linq_where:(LINQCondition)predicate
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    for(id item in self) {
       if (predicate(item)) {
           [result addObject:item];
       }
    }
    return result;
}

/// shouldStopOnError为YES 一旦transform返回nil 函数返回nil 否则用NSNull代替
/// 类似map效果
- (NSArray *)linq_select:(LINQSelector)transform
          andStopOnError:(BOOL)shouldStopOnError
{
    NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count];
    for(id item in self)
    {
        id object = transform(item);
        if (nil != object)
        {
            [result addObject: object];
        }
        else
        {
            if (shouldStopOnError)
            {
                return nil;
            }
            else
            {
                [result addObject: [NSNull null]];
            }
        }
    }
    return result;
}

- (NSArray *)linq_select:(LINQSelector)transform
{
    return [self linq_select: transform
              andStopOnError: NO];
}

- (NSArray*)linq_selectAndStopOnNil:(LINQSelector)transform
{
    return [self linq_select: transform
              andStopOnError: YES];
}

/// keySelector接收对象返回一个用于比较的值 按这个值升序
- (NSArray *)linq_sort:(LINQSelector)keySelector
{
    return [self sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        id valueOne = keySelector(obj1);
        id valueTwo = keySelector(obj2);
        NSComparisonResult result = [valueOne compare:valueTwo];
        return result;
    }];
}

/// 按存储的对象本身升序 用compare:
- (NSArray *)linq_sort
{
    return [self linq_sort:^id(id item) { return item;} ];
}

/// 降序
- (NSArray *)linq_sortDescending:(LINQSelector)keySelector
{
    return [self sortedArrayUsingComparator:^NSComparisonResult(id obj2, id obj1) {
        id valueOne = keySelector(obj1);
        id valueTwo = keySelector(obj2);
        NSComparisonResult result = [valueOne compare:valueTwo];
        return result;
    }];
}

/// 降序
- (NSArray *)linq_sortDescending
{
    return [self linq_sortDescending:^id(id item) { return item;} ];
}

/// filter效果 类的实例
- (NSArray *)linq_ofType:(Class)type
{
    return [self linq_where:^BOOL(id item) {
        return [[item class] isSubclassOfClass:type];
    }];
}

/// 每项对应一个数组 将数组的项全部添加到结果 1-n
- (NSArray *)linq_selectMany:(LINQSelector)transform
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    for(id item in self) {
        for(id child in transform(item)){
            [result addObject:child];
        }
    }
    return result;
}

/// 返回去重后的数组
- (NSArray *)linq_distinct
{
    NSMutableArray* distinctSet = [[NSMutableArray alloc] init];
    for (id item in self) {
        if (![distinctSet containsObject:item]) {
            [distinctSet addObject:item];
        }
    }
    return distinctSet;
}

/// 映射结果去重
- (NSArray *)linq_distinct:(LINQSelector)keySelector
{
    NSMutableSet* keyValues = [[NSMutableSet alloc] init];
    NSMutableArray* distinctSet = [[NSMutableArray alloc] init];
    for (id item in self) {
        id keyForItem = keySelector(item);
        if (!keyForItem)
            keyForItem = [NSNull null];
        if (![keyValues containsObject:keyForItem]) {
            [distinctSet addObject:item];
            [keyValues addObject:keyForItem];
        }
    }
    return distinctSet;
}

/// 聚集
- (id)linq_aggregate:(LINQAccumulator)accumulator
{
    id aggregate = nil;
    for (id item in self) {
        if (aggregate == nil) {
            aggregate = item;
        } else {
            aggregate = accumulator(item, aggregate);
        }
    }
    return aggregate;
}

- (id)linq_firstOrNil
{
    return self.count == 0 ? nil : [self objectAtIndex:0];
}

/// 返回第一个通过predicate的项
- (id)linq_firstOrNil:(LINQCondition)predicate
{
    for(id item in self) {
        if (predicate(item)) {
            return item;
        }
    }
    return nil;
}

- (id)linq_lastOrNil
{
    return self.count == 0 ? nil : [self objectAtIndex:self.count - 1];
}

/// 子数组 skip
- (NSArray*)linq_skip:(NSUInteger)count
{
    if (count < self.count) {
        NSRange range = {.location = count, .length = self.count - count};
        return [self subarrayWithRange:range];
    } else {
        return @[];
    }
}

/// 子数组 only take
- (NSArray*)linq_take:(NSUInteger)count
{
    NSRange range = { .location=0,
        .length = count > self.count ? self.count : count};
    return [self subarrayWithRange:range];
}

- (BOOL)linq_any:(LINQCondition)condition
{
    for (id item in self) {
        if (condition(item)) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)linq_all:(LINQCondition)condition
{
    for (id item in self) {
        if (!condition(item)) {
            return NO;
        }
    }
    return YES;
}

/// 分组 返回字典 key为groupKeySelector返回的值nil对应NSNull value为数组
- (NSDictionary*)linq_groupBy:(LINQSelector)groupKeySelector
{
    NSMutableDictionary* groupedItems = [[NSMutableDictionary alloc] init];
    for (id item in self) {
        id key = groupKeySelector(item);
        if (!key)
            key = [NSNull null];
        NSMutableArray* arrayForKey;
        if (!(arrayForKey = [groupedItems objectForKey:key])){
            arrayForKey = [[NSMutableArray alloc] init];
            [groupedItems setObject:arrayForKey forKey:key];
        }
        [arrayForKey addObject:item];
    }
    return groupedItems;
}

/// 值->(key:value) key由keySelector计算 value由valueSelector
/// 返回nil的话会用NSNull代替 多个key返回NSNull会导致值丢失
/// valueSelector为nil时value就说item
- (NSDictionary *)linq_toDictionaryWithKeySelector:(LINQSelector)keySelector valueSelector:(LINQSelector)valueSelector
{
    NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
    for (id item in self) {
        id key = keySelector(item);
        id value = valueSelector!=nil ? valueSelector(item) : item;
        
        if (!key)
            key = [NSNull null];
        if (!value)
            value = [NSNull null];
        
        [result setObject:value forKey:key];
    }
    return result;
}

- (NSDictionary *)linq_toDictionaryWithKeySelector:(LINQSelector)keySelector
{
    return [self linq_toDictionaryWithKeySelector:keySelector valueSelector:nil];
}

- (NSUInteger)linq_count:(LINQCondition)condition
{
    return [self linq_where:condition].count;
}

- (NSArray *)linq_concat:(NSArray *)array
{
    NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count + array.count];
    [result addObjectsFromArray:self];
    [result addObjectsFromArray:array];
    return result;
}

- (NSArray *)linq_reverse
{
    NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:self.count];
    for (id item in [self reverseObjectEnumerator]) {
        [result addObject:item];
    }
    return result;
}

- (NSNumber *)linq_sum
{
    return [self valueForKeyPath: @"@sum.self"];
}

@end
