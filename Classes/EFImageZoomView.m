/**
 * Image zoom view.
 *
 * Based on PhotoScroller example, Copyright (c) 2010 Apple Inc. All Rights Reserved.
 */

#import "EFImageZoomView.h"
#import "EFImageScrollView.h"

@implementation EFImageZoomView

@synthesize imageScrollView=imageScrollView_, index=index_;

- (id)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.showsVerticalScrollIndicator = NO;
		self.showsHorizontalScrollIndicator = NO;
		self.bouncesZoom = YES;
		self.decelerationRate = UIScrollViewDecelerationRateFast;
		self.delegate = self;

		UITapGestureRecognizer *tapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(zoomOut:)] autorelease];
		[tapRecognizer setNumberOfTapsRequired:2];
		[self addGestureRecognizer:tapRecognizer];
	}
	return self;
}

- (void)dealloc {
	[contentView_ release];
	contentView_ = nil;
	[lowResolutionImageView_ release];
	lowResolutionImageView_ = nil;
	[imageView_ release];
	imageView_ = nil;
	[super dealloc];
}

- (void)zoomOut:(UITapGestureRecognizer *)recognizer {
	self.zoomScale = self.minimumZoomScale;
}

#pragma mark -
#pragma mark Override layoutSubviews to center content

- (void)layoutSubviews  {
	[super layoutSubviews];

	CGSize boundsSize = self.bounds.size;
	CGRect frameToCenter = contentView_.frame;

	// center horizontally
	if (frameToCenter.size.width < boundsSize.width) {
		frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2;
	} else {
		frameToCenter.origin.x = 0;
	}

	// center vertically
	if (frameToCenter.size.height < boundsSize.height) {
		frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2;
	} else {
		frameToCenter.origin.y = 0;
	}

	contentView_.frame = frameToCenter;
}

#pragma mark -
#pragma mark UIScrollView delegate methods

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return contentView_;
}

#pragma mark -
#pragma mark Configure scrollView to display new image (tiled or not)

- (void)displayImage:(NSIndexPath *)indexPath {
	id <EFImage> image = [self.imageScrollView.dataSource imageView:self.imageScrollView imageAtIndexPath:indexPath];
	CGSize size = [image sizeForVersion:self.imageScrollView.imageVersion];

	// clear previous views
	[contentView_ removeFromSuperview];
	[contentView_ release];
	contentView_ = nil;

	[lowResolutionImageView_ release];
	lowResolutionImageView_ = nil;

	[imageView_ release];
	imageView_ = nil;

	// reset our zoomScale to 1.0 before doing any further calculations
	self.zoomScale = 1.0;

	// create the content view
	contentView_ = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height)];
	[self addSubview:contentView_];

	// make a new view for the low resolution image
	if (self.imageScrollView.lowResolutionImageVersion != nil) {
		NSString *imagePath = [image pathForVersion:self.imageScrollView.lowResolutionImageVersion];
		UIImage *image = [UIImage imageWithContentsOfFile:imagePath];

		lowResolutionImageView_ = [[UIImageView alloc] initWithImage:image];
		lowResolutionImageView_.frame = contentView_.frame;

		[contentView_ addSubview:lowResolutionImageView_];
		[contentView_ sendSubviewToBack:lowResolutionImageView_];
	}

	// make a new tiled view for the standard image
	if (self.imageScrollView.renderMode == EFImageScrollViewRenderModePlain) {
		imageView_ = [[EFTilingView alloc] initWithImage:image
			     version:self.imageScrollView.imageVersion];
	} else {
		imageView_ = [[EFTilingView alloc] initWithImage:image
			     version:self.imageScrollView.imageVersion
			     tileSize:self.imageScrollView.tileSize
			     levelsOfDetail:self.imageScrollView.levelsOfDetail];
	}

	[contentView_ addSubview:imageView_];

	self.contentSize = size;
	[self setMaxMinZoomScalesForCurrentBounds];
	self.zoomScale = self.minimumZoomScale;
}

- (void)setMaxMinZoomScalesForCurrentBounds {
	CGSize boundsSize = self.bounds.size;
	CGSize imageSize = contentView_.bounds.size;

	// calculate min/max zoomscale
	CGFloat xScale = boundsSize.width / imageSize.width; // the scale needed to perfectly fit the image width-wise
	CGFloat yScale = boundsSize.height / imageSize.height; // the scale needed to perfectly fit the image height-wise
	CGFloat minScale = MIN(xScale, yScale);             // use minimum of these to allow the image to become fully visible

	// on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
	// maximum zoom scale to 0.5.
	CGFloat scale = 1.0; // [[UIScreen mainScreen] scale];
	CGFloat maxScale = 1.0 / scale;

	// don't let minScale exceed maxScale. (If the image is smaller than the screen, we don't want to force it to be zoomed.)
	if (minScale > maxScale) {
		minScale = maxScale;
	}

	self.maximumZoomScale = maxScale;
	self.minimumZoomScale = minScale;
}

#pragma mark -
#pragma mark Methods called during rotation to preserve the zoomScale and the visible portion of the image

// returns the center point, in image coordinate space, to try to restore after rotation.
- (CGPoint)pointToCenterAfterRotation {
	CGPoint boundsCenter = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
	return [self convertPoint:boundsCenter toView:contentView_];
}

// returns the zoom scale to attempt to restore after rotation.
- (CGFloat)scaleToRestoreAfterRotation {
	CGFloat contentScale = self.zoomScale;

	// If we're at the minimum zoom scale, preserve that by returning 0, which will be converted to the minimum
	// allowable scale when the scale is restored.
	if (contentScale <= self.minimumZoomScale + FLT_EPSILON) {
		contentScale = 0;
	}

	return contentScale;
}

- (CGPoint)maximumContentOffset {
	CGSize contentSize = self.contentSize;
	CGSize boundsSize = self.bounds.size;
	return CGPointMake(contentSize.width - boundsSize.width, contentSize.height - boundsSize.height);
}

- (CGPoint)minimumContentOffset {
	return CGPointZero;
}

// Adjusts content offset and scale to try to preserve the old zoomscale and center.
- (void)restoreCenterPoint:(CGPoint)oldCenter scale:(CGFloat)oldScale {
	// Step 1: restore zoom scale, first making sure it is within the allowable range.
	self.zoomScale = MIN(self.maximumZoomScale, MAX(self.minimumZoomScale, oldScale));

	// Step 2: restore center point, first making sure it is within the allowable range.

	// 2a: convert our desired center point back to our own coordinate space
	CGPoint boundsCenter = [self convertPoint:oldCenter fromView:imageView_];
	// 2b: calculate the content offset that would yield that center point
	CGPoint offset = CGPointMake(boundsCenter.x - self.bounds.size.width / 2.0,
				     boundsCenter.y - self.bounds.size.height / 2.0);
	// 2c: restore offset, adjusted to be within the allowable range
	CGPoint maxOffset = [self maximumContentOffset];
	CGPoint minOffset = [self minimumContentOffset];
	offset.x = MAX(minOffset.x, MIN(maxOffset.x, offset.x));
	offset.y = MAX(minOffset.y, MIN(maxOffset.y, offset.y));
	self.contentOffset = offset;
}

@end