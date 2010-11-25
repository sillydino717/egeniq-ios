//
//  EFSpecifierCell.m
//  AxisControl
//
//  Created by Peter Verhage on 24-11-10.
//  Copyright 2010 Egeniq. All rights reserved.
//

#import "EFSpecifierCell.h"

@implementation EFSpecifierCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
   return [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
}

- (NSString *)title {
	return self.textLabel.text;
}

- (void)setTitle:(NSString *)title {
	self.textLabel.text = title;
}

@end
