//
//  UPCardsCarousel.m
//  UPCardsCarousel
//
//  Created by Paul ULRIC on 08/06/2014.
//  Copyright (c) 2014 Paul ULRIC. All rights reserved.
//

#import "UPCardsCarousel.h"


const static NSUInteger     kMaxVisibleCardsDefault         = 6;
const static NSUInteger     kHiddenDeckZPositionOffset      = 10;
const static NSTimeInterval kMovingAnimationDurationDefault = .4f;
const static CGFloat        kLabelsContainerHeight          = 60;


@interface UPCardsCarousel() {
    UIView *_cardsContainer;
    NSMutableArray *_visibleCards;
    NSUInteger _numberOfCards;
    NSUInteger _visibleCardIndex;
    NSUInteger _visibleCardsOffset;
    
    NSUInteger _hiddenDeckZPositionOffset;
    NSUInteger _visibleDeckZPositionOffset;
    NSUInteger _movingDeckZPositionOffset;
}

@end



@implementation UPCardsCarousel


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupElements];
        [self setDefaultValues];
    }
    return self;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupElements];
        [self setDefaultValues];
        
    }
    return self;
}

- (void)dealloc
{
    [_cardsContainer removeObserver:self forKeyPath:@"frame"];
}


- (void)setDataSource:(id<UPCardsCarouselDataSource>)dataSource
{
    if (_dataSource != dataSource) {
        _dataSource = dataSource;
        if (_dataSource) {
            [self reloadData];
        }
    }
}


#pragma mark - UI Set Up

-(void) setDefaultValues
{
    [self setLabelBannerPosition:UPCardsCarouselLabelBannerLocation_bottom];
    [self setMaxVisibleCardsCount:kMaxVisibleCardsDefault];
    [self setMovingAnimationDuration:kMovingAnimationDurationDefault];
    [self setDoubleTapToTop:YES];
}


- (void)setupElements
{
    [self setupCardsView];
    _visibleCards = [NSMutableArray new];
}

- (void)setupCardsView
{
    CGRect frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height - kLabelsContainerHeight);
    _cardsContainer = [[UIView alloc] initWithFrame:frame];
    [_cardsContainer setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
    [_cardsContainer setBackgroundColor:[UIColor clearColor]];
    [_cardsContainer addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
    _cardsContainer.clipsToBounds = TRUE;
    
    UISwipeGestureRecognizer *previousSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeToPrevious:)];
    [previousSwipe setDirection:UISwipeGestureRecognizerDirectionLeft];
    [self addGestureRecognizer:previousSwipe];
    
    UISwipeGestureRecognizer *nextSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeToNext:)];
    [nextSwipe setDirection:UISwipeGestureRecognizerDirectionRight];
    [self addGestureRecognizer:nextSwipe];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTouchCard:)];
    [self addGestureRecognizer:tap];
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTap:)];
    [doubleTap setNumberOfTapsRequired:2];
    [self addGestureRecognizer:doubleTap];
    
    [self addSubview:_cardsContainer];
}


#pragma mark - Data Management

- (void)reloadData
{
    [self reloadDataWithCurrentIndex:0];
}

- (void)reloadDataWithCurrentIndex:(NSUInteger)index
{
    for (UIView *card in _visibleCards) {
        [card removeFromSuperview];
    }
    [_visibleCards removeAllObjects];

    
    if (!_dataSource)
        return;
    
    _numberOfCards = [_dataSource numberOfCardsInCarousel:self];
    
    if(_numberOfCards <= 0)
        return;
    
    int cardsCount = (int)MIN(_numberOfCards, self.maxVisibleCardsCount);
    
    _hiddenDeckZPositionOffset = kHiddenDeckZPositionOffset;
    _visibleDeckZPositionOffset = _hiddenDeckZPositionOffset + cardsCount;
    _movingDeckZPositionOffset = _visibleDeckZPositionOffset + cardsCount;
    
    NSInteger start = index - cardsCount/2;
    NSInteger end = index + cardsCount/2;
    if(start < 0) {
        start = 0;
        end = cardsCount;
    }
    if(index + (cardsCount/2 - 1) >= _numberOfCards) {
        start = _numberOfCards - cardsCount;
        end = _numberOfCards;
    }
    
    for(NSUInteger i = start; i < end; i++) {
        UIView *card = [_dataSource carousel:self viewForCardAtIndex:i];
        [card setUserInteractionEnabled:YES];
        
        BOOL visible = (i >= index);
        [self positionCard:card toVisible:visible];
        NSUInteger offset = i - start;
        NSInteger zIndex = visible ? _visibleDeckZPositionOffset+(cardsCount-1-offset) : _hiddenDeckZPositionOffset+offset;
        [card.layer setZPosition:zIndex];
        
        [_cardsContainer insertSubview:card atIndex:0];
        
        [_visibleCards addObject:card];
    }
    _visibleCardIndex = index - start;
    _visibleCardsOffset = start;
    
    [self slideVisibleCardDown];
    

    
    if(_delegate) {
        NSUInteger displayedCardIndex = _visibleCardsOffset+_visibleCardIndex;
        if([_delegate respondsToSelector:@selector(carousel:willDisplayCardAtIndex:)])
            [_delegate carousel:self willDisplayCardAtIndex:displayedCardIndex];
        if([_delegate respondsToSelector:@selector(carousel:didDisplayCardAtIndex:)])
            [_delegate carousel:self didDisplayCardAtIndex:displayedCardIndex];
    }
}

- (void)reloadNumberOfCards
{
    _numberOfCards = [_dataSource numberOfCardsInCarousel:self];
}

- (void)reloadCardAtIndex:(NSUInteger)index
{
    NSInteger localIndex = index - _visibleCardsOffset;
    
    if(localIndex < 0 || localIndex >= [_visibleCards count])
        return;
    
    UIView *oldCard = [_visibleCards objectAtIndex:localIndex];
    UIView *newCard = [_dataSource carousel:self viewForCardAtIndex:index];
    [_visibleCards replaceObjectAtIndex:localIndex withObject:newCard];
    
    CGAffineTransform transform = [oldCard.layer affineTransform];
    [oldCard.layer setAffineTransform:CGAffineTransformIdentity];
    [newCard setFrame:[oldCard frame]];
    [newCard.layer setAffineTransform:transform];
    [newCard.layer setZPosition:[oldCard.layer zPosition]];
    [_cardsContainer addSubview:newCard];
    [oldCard removeFromSuperview];
}


- (UIView*)cardAtIndex:(NSUInteger)index
{
    NSInteger localIndex = index - _visibleCardsOffset;
    
    if(localIndex < 0 || localIndex >= [_visibleCards count])
        return nil;
    
    return [_visibleCards objectAtIndex:localIndex];
}


#pragma mark - UI Helpers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([object isEqual:_cardsContainer] && [keyPath isEqualToString:@"frame"]) {
        /* When the cards container's frame changes, need to re-center the cards.
         * Setting a flexible top margin auto-resizing mask to the cards doesn't work.
         * So do it manually.
         */
//        for(int i = 0; i < [_visibleCards count]; i++) {
//            UIImageView *card = [_visibleCards objectAtIndex:i];
//            CGPoint center;
//            if(i < _visibleCardIndex) {
//                int yOffset = arc4random()%20 - 10;
//                center = CGPointMake(40-card.frame.size.width/2, _cardsContainer.frame.size.height/2 + yOffset);
//            } else {
//                center = CGPointMake(10+_cardsContainer.frame.size.width/2, _cardsContainer.frame.size.height/2);
//            }
//            [card setCenter:center];
//        }
        
        for(int i = 0; i < [_visibleCards count]; i++) {
            UIImageView *card = [_visibleCards objectAtIndex:i];
            CGPoint center = _cardsContainer.center;
            [card setCenter:center];
        }

    }
}

- (void)positionCard:(UIView*)card toVisible:(BOOL)visible
{
    CGPoint center;
//    if(visible) {
//        center = CGPointMake(10+_cardsContainer.frame.size.width/2, _cardsContainer.frame.size.height/2);
//    } else {
//        int yOffset = arc4random()%20 - 10;
//        center = CGPointMake(40-card.frame.size.width/2, _cardsContainer.frame.size.height/2 + yOffset);
//    }
//    int radians = arc4random()%20 - 10;
//    float angle = (M_PI * (radians) / 180.0);
//    [card.layer setAffineTransform:CGAffineTransformMakeRotation(angle)];
    
    if (visible){
        center = _cardsContainer.center;
    }else {
        center = CGPointMake(_cardsContainer.center.x + _cardsContainer.frame.origin.x + _cardsContainer.frame.size.width, _cardsContainer.center.y);
    }
    
    
    
    [card setCenter:center];
}

- (void)slideVisibleCardDown{
    
    [UIView animateWithDuration:self.movingAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         for (UIView *card in _visibleCards) {
                             CGPoint center = CGPointMake(card.center.x, _cardsContainer.center.y);
                             [card setCenter:center];
                         }
                         UIView *visibleCard = [_visibleCards objectAtIndex:_visibleCardIndex];
                         [self positionCard:visibleCard offsetY:10];
                     } completion:^(BOOL finished) {

                     }];
    

}

- (void)positionCard:(UIView*)card offsetY:(float)y
{
    CGPoint center = CGPointMake(card.center.x, _cardsContainer.center.y + y);
    [card setCenter:center];
}

/*
 If the max number of cards is displayed, the dataSource
 may have more cards to supply.
 When at the middle of the deck, look for an additional
 card in the dataSource. If there is one, add it under
 the visible or the hidden deck, according to the swipe way.
 */
- (void)addInfiniteCardsForWay:(NSNumber*)way
{
    // way = -1 -> previous | way = 1 -> next
    NSUInteger wayValue = [way integerValue];
    
    NSInteger newCardOffset = (wayValue == -1) ? -1 : [_visibleCards count];
    NSInteger newCardIndex = _visibleCardsOffset + newCardOffset;
    
    if((wayValue == -1 && newCardIndex >= 0) || (wayValue == 1 && newCardIndex < _numberOfCards)) {
        NSInteger oldCardIndex = (wayValue == -1) ? [_visibleCards count]-1 : 0;
        UIImageView *oldCard = [_visibleCards objectAtIndex:oldCardIndex];
        [_visibleCards removeObjectAtIndex:oldCardIndex];
        _visibleCardIndex += (wayValue*-1);
        _visibleCardsOffset += wayValue;
        
        NSUInteger newCardVisibleIndex = (wayValue == -1) ? 0 : [_visibleCards count];
        NSInteger newCardZPosition = (wayValue == -1) ? _hiddenDeckZPositionOffset-1 : _visibleDeckZPositionOffset-1;
        UIView *newCard = [_dataSource carousel:self viewForCardAtIndex:newCardIndex];
        [_visibleCards insertObject:newCard atIndex:newCardVisibleIndex];
        [newCard setUserInteractionEnabled:YES];
        
        [self positionCard:newCard toVisible:(wayValue == 1)];
        [newCard.layer setZPosition:newCardZPosition];
        [newCard setAlpha:0.0f];
        [_cardsContainer insertSubview:newCard atIndex:0];
        
        for(int i = 0; i < [_visibleCards count]; i++) {
            // Don't recompute the moving card z-index, it will be set at the end of the animation
            if((wayValue == -1 && i == _visibleCardIndex) || (wayValue == 1 && i == _visibleCardIndex-1))
                continue;
            UIImageView *card = [_visibleCards objectAtIndex:i];
            NSInteger zIndex = (i < _visibleCardIndex) ? _hiddenDeckZPositionOffset+i : _visibleDeckZPositionOffset+([_visibleCards count]-1-i);
            [card.layer setZPosition:zIndex];
        }
        
        [UIView animateWithDuration:self.movingAnimationDuration
                              delay:0.0f
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             [newCard setAlpha:1.0f];
                             [oldCard setAlpha:0.0f];
                         } completion:^(BOOL finished) {
                             [oldCard removeFromSuperview];
                         }];
    }
}

#pragma mark - 

- (void)showNext{
    if(_visibleCardIndex >= [_visibleCards count]-1)
        return;
    
    UIView *movedCard = [_visibleCards objectAtIndex:_visibleCardIndex];
    
    NSUInteger zIndex = _visibleCardIndex;
    
    _visibleCardIndex++;
    
    
    NSUInteger displayedCardIndex = _visibleCardsOffset+_visibleCardIndex;
    NSUInteger hiddenCardIndex = displayedCardIndex-1;
    if(_delegate) {
        if([_delegate respondsToSelector:@selector(carousel:willHideCardAtIndex:)])
            [_delegate carousel:self willHideCardAtIndex:hiddenCardIndex];
        if([_delegate respondsToSelector:@selector(carousel:willDisplayCardAtIndex:)])
            [_delegate carousel:self willDisplayCardAtIndex:displayedCardIndex];
    }
    
    
    
    [UIView animateWithDuration:self.movingAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         [self positionCard:movedCard toVisible:NO];
                         
                         [movedCard.layer setZPosition:_movingDeckZPositionOffset + zIndex];
                     } completion:^(BOOL finished) {
                         NSUInteger movedCardIndex = [_visibleCards indexOfObject:movedCard];
                         NSInteger zPosition = _hiddenDeckZPositionOffset;
                         if(movedCardIndex > 0 && movedCardIndex < [_visibleCards count]) {
                             UIView *previousCard = [_visibleCards objectAtIndex:movedCardIndex-1];
                             zPosition = [previousCard.layer zPosition] + 1;
                         }
                         [movedCard.layer setZPosition:zPosition];
                         
                         
                         
                         if(_delegate) {
                             if([_delegate respondsToSelector:@selector(carousel:didHideCardAtIndex:)])
                                 [_delegate carousel:self didHideCardAtIndex:hiddenCardIndex];
                             if([_delegate respondsToSelector:@selector(carousel:didDisplayCardAtIndex:)])
                                 [_delegate carousel:self didDisplayCardAtIndex:displayedCardIndex];
                         }
                     }];
    
    [self slideVisibleCardDown];
    
    if([_visibleCards count] == self.maxVisibleCardsCount && _visibleCardIndex > [_visibleCards count] / 2)
        [self addInfiniteCardsForWay:@1];
    

}

- (void)showPrevious{
    if(_visibleCardIndex == 0)
        return;
    
    _visibleCardIndex--;
    
    NSUInteger displayedCardIndex = _visibleCardsOffset+_visibleCardIndex;
    NSUInteger hiddenCardIndex = displayedCardIndex+1;
    if(_delegate) {
        if([_delegate respondsToSelector:@selector(carousel:willHideCardAtIndex:)])
            [_delegate carousel:self willHideCardAtIndex:hiddenCardIndex];
        if([_delegate respondsToSelector:@selector(carousel:willDisplayCardAtIndex:)])
            [_delegate carousel:self willDisplayCardAtIndex:displayedCardIndex];
    }
    
    UIView *movedCard = [_visibleCards objectAtIndex:_visibleCardIndex];
    NSUInteger zIndex = [_visibleCards count]-1 - _visibleCardIndex;
    
    [UIView animateWithDuration:self.movingAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         [self positionCard:movedCard toVisible:YES];
                         
                         [movedCard.layer setZPosition:_movingDeckZPositionOffset + zIndex];
                     } completion:^(BOOL finished) {
                         NSUInteger movedCardIndex = [_visibleCards indexOfObject:movedCard];
                         NSInteger zPosition = _visibleDeckZPositionOffset;
                         if(movedCardIndex < [_visibleCards count] - 1) {
                             UIView *nextCard = [_visibleCards objectAtIndex:movedCardIndex+1];
                             zPosition = [nextCard.layer zPosition] + 1;
                         }
                         [movedCard.layer setZPosition:zPosition];
                         
                         
                         
                         if(_delegate) {
                             if([_delegate respondsToSelector:@selector(carousel:didHideCardAtIndex:)])
                                 [_delegate carousel:self didHideCardAtIndex:hiddenCardIndex];
                             if([_delegate respondsToSelector:@selector(carousel:didDisplayCardAtIndex:)])
                                 [_delegate carousel:self didDisplayCardAtIndex:displayedCardIndex];
                         }
                     }];
    
    [self slideVisibleCardDown];
    
    if([_visibleCards count] == self.maxVisibleCardsCount && _visibleCardIndex < [_visibleCards count] / 2)
        [self addInfiniteCardsForWay:@-1];
    

}

#pragma mark - Cards Interactions

- (void)didSwipeToPrevious:(UISwipeGestureRecognizer*)swipeGesture
{
    [self showPrevious];
}


- (void)didSwipeToNext:(UISwipeGestureRecognizer*)swipeGesture
{
    [self showNext];
}

- (void)didDoubleTap:(UITapGestureRecognizer*)tapGesture
{
    if(_visibleCardIndex == 0)
        return;
    
    if(!_doubleTapToTop)
        return;
    
    CGPoint touchLocation = [tapGesture locationInView:self];
    UIView *card = [_visibleCards objectAtIndex:_visibleCardIndex - 1];
    if(CGRectContainsPoint(card.frame, touchLocation)) {
        [self reloadData];
    }
}

- (void)didTouchCard:(UITapGestureRecognizer*)tapGesture
{
    if([_visibleCards count] == 0)
        return;
    
    if(!_delegate || ![_delegate respondsToSelector:@selector(carousel:didTouchCardAtIndex:)])
        return;
    
    CGPoint touchLocation = [tapGesture locationInView:self];
    UIView *card = [_visibleCards objectAtIndex:_visibleCardIndex];
    if(CGRectContainsPoint(card.frame, touchLocation)) {
        NSUInteger index = _visibleCardsOffset + _visibleCardIndex;
        [_delegate carousel:self didTouchCardAtIndex:index];
    }
}



@end
