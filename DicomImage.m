/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://homepage.mac.com/rossetantoine/osirix/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

/***************************************** Modifications *********************************************

Version 2.3

	20051221	LP	Added outline for graphicAnnotationSequence. this allow creation of a DICOM Presentation state IOD for export
	
Version 2.5

	20060809	DDP	Renamed clearComplePathCache to clearCompletePathCache
	
*******************************************************************************************************/


#import "DicomImage.h"
#import "browserController.h"
#import "BonjourBrowser.h"
#import <OsiriX/DCM.h>
#import "DCMView.h"
#import "DCMPix.h"

extern NSString * documentsDirectory();

@implementation DicomImage

- (NSString*) fileType
{
	NSString	*f = [self primitiveValueForKey:@"fileType"];
	
	if( f == 0 || [f isEqualToString:@""]) return @"DICOM";
	else return f;
}

- (NSString*) type
{
	return @"Image";
}

- (void) dealloc
{
	[completePathCache release];
	[super dealloc];
}

/*
- (void)finalize {
	//nothing to do does not need to be called
}
*/

-(NSString*) uniqueFilename	// Return a 'unique' filename that identify this image...
{
	return [NSString stringWithFormat:@"%@ %@",[self valueForKey:@"sopInstanceUID"], [self valueForKey:@"instanceNumber"]];
}

- (void) clearCompletePathCache
{
	[completePathCache release];
	completePathCache = 0L;
}

-(NSString*) completePath
{
	if( completePathCache) return completePathCache;
	
	if( [[self valueForKey:@"inDatabaseFolder"] boolValue] == YES)
	{
		NSString			*path = [self primitiveValueForKey:@"path"];
		BrowserController	*cB = [BrowserController currentBrowser];
		
		if( [path cString] [ 0] != '/')
		{
			if( [cB isCurrentDatabaseBonjour])
			{
//				NSLog( @"*** Warning - CompletePath on Shared Database");
				completePathCache = [[[cB bonjourBrowser] getDICOMFile: [cB currentBonjourService] forObject: self noOfImages: 1] retain];
			}
			else
			{
				NSString	*extension = [path pathExtension];
				long		val = [[path stringByDeletingPathExtension] intValue];
				NSString	*dbLocation = [[cB fixedDocumentsDirectory] stringByAppendingPathComponent: @"DATABASE"];
				
				val /= 10000;
				val++;
				val *= 10000;
				
				completePathCache = [[[dbLocation stringByAppendingPathComponent: [NSString stringWithFormat: @"%d", val]] stringByAppendingPathComponent: path] retain];
			}
			
			return completePathCache;
		}
	}
	
	return [self primitiveValueForKey:@"path"];
}

- (BOOL)validateForDelete:(NSError **)error
{
	BOOL delete = [super validateForDelete:(NSError **)error];
	if (delete)
	{
		if( [[self valueForKey:@"inDatabaseFolder"] boolValue] == YES)
		{
			[[BrowserController currentBrowser] addFileToDeleteQueue: [self valueForKey:@"completePath"]];
			
			NSString *pathExtension = [[self valueForKey:@"path"] pathExtension];
			
			if( [pathExtension isEqualToString:@"hdr"])		// ANALYZE -> DELETE IMG
			{
				[[BrowserController currentBrowser] addFileToDeleteQueue: [[[self valueForKey:@"completePath"] stringByDeletingPathExtension] stringByAppendingPathExtension:@"img"]];
			}
			else if([pathExtension isEqualToString:@"zip"])		// ZIP -> DELETE XML
			{
				[[BrowserController currentBrowser] addFileToDeleteQueue: [[[self valueForKey:@"completePath"] stringByDeletingPathExtension] stringByAppendingPathExtension:@"xml"]];
			}
			
			[self setValue:[NSNumber numberWithBool:NO] forKey:@"inDatabaseFolder"];
		}
	}
	return delete;
}

- (NSSet *)paths{
	return [NSSet setWithObject:[self completePath]];
}

// DICOM Presentation State
- (DCMSequenceAttribute *)graphicAnnotationSequence{
	//main sequnce that includes the graphics overlays : ROIs and annotation
	DCMSequenceAttribute *graphicAnnotationSequence = [DCMSequenceAttribute sequenceAttributeWithName:@"GraphicAnnotationSequence"];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	//need the original file to get SOPClassUID and possibly SOPInstanceUID
	DCMObject *imageObject = [DCMObject objectWithContentsOfFile:[self primitiveValueForKey:@"completePath"] decodingPixelData:NO];
	
	//ref image sequence only has one item.
	DCMSequenceAttribute *refImageSequence = [DCMSequenceAttribute sequenceAttributeWithName:@"ReferencedImageSequence"];
	DCMObject *refImageObject = [DCMObject dcmObject];
	[refImageObject setAttributeValues:[self primitiveValueForKey:@"sopInstanceUID"] forName:@"ReferencedSOPInstanceUID"];
	[refImageObject setAttributeValues:[[imageObject attributeValueWithName:@"SOPClassUID"] values] forName:@"ReferencedSOPClassUID"];
	// may need to add references frame number if we add a frame object  Nothing here yet.
	
	[refImageSequence addItem:refImageObject];
	
	// Some basic graphics info
	
	DCMAttribute *graphicAnnotationUnitsAttr = [DCMAttribute attributeWithAttributeTag:[DCMAttributeTag tagWithName:@"GraphicAnnotationUnits"]];
	[graphicAnnotationUnitsAttr setValues:[NSMutableArray arrayWithObject:@"PIXEL"]];
	
	
	
	//loop through the ROIs and add
	NSSet *rois = [self primitiveValueForKey:@"rois"];
	NSEnumerator *enumerator = [rois objectEnumerator];
	id roi;
	while (roi = [enumerator nextObject]){
		//will be either a Graphic Object sequence or a Text Object Sequence
		int roiType = [[roi valueForKey:@"roiType"] intValue];
		NSString *typeString = nil;
		if (roiType == tText) {// is text 
		}
		else // is a graphic
		{
			switch (roiType) {
				case tOval:
					typeString = @"ELLIPSE";
					break;
				case tOPolygon:
				case tCPolygon:
					typeString = @"POLYLINE";
					break;
			}
		}
		
	}	
	[pool release];
	 return graphicAnnotationSequence;
}

- (NSImage *)image
{
	DCMPix *pix = [[DCMPix alloc] myinit:[self valueForKey:@"completePath"] :0 :0 :0L :0 :[[self valueForKeyPath:@"series.id"] intValue] isBonjour:NO imageObj:self];
	//[pix computeWImage:NO :[[self valueForKeyPath:@"series.windowLevel"] floatValue] :[[self valueForKeyPath:@"series.windowWidth"] floatValue]];
	[pix computeWImage:NO :0 :0];
	NSData	*data = [[pix getImage] TIFFRepresentation];
	NSImage *thumbnail = [[[NSImage alloc] initWithData: data] autorelease];

	[pix release];
	return thumbnail;

}
- (NSImage *)thumbnail{
	DCMPix *pix = [[DCMPix alloc] myinit:[self valueForKey:@"completePath"] :0 :0 :0L :0 :[[self valueForKeyPath:@"series.id"] intValue] isBonjour:NO imageObj:self];
	//[pix computeWImage:YES :[[self valueForKeyPath:@"series.windowLevel"] floatValue] :[[self valueForKeyPath:@"series.windowWidth"] floatValue]];
	[pix computeWImage:YES :0 :0];
	NSData	*data = [[pix getImage] TIFFRepresentation];
	NSImage *thumbnail = [[[NSImage alloc] initWithData: data] autorelease];
	[pix release];
	return thumbnail;
}

- (NSDictionary *)dictionary{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	return dict;
}
	


@end
