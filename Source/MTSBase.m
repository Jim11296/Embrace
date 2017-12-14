// (c) 2011-2017 musictheory.net, LLC


#import "MTSBase.h"


extern NSString *MTSGetHexStringWithData(NSData *data)
{
    if (!data) return nil;

    NSUInteger inLength  = [data length];
    unichar *outCharacters = malloc(sizeof(unichar) * (inLength * 2));

    UInt8 *inBytes = (UInt8 *)[data bytes];
    static const char lookup[] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };
 
    NSUInteger i, o = 0;
    for (i = 0; i < inLength; i++) {
        UInt8 inByte = inBytes[i];
        outCharacters[o++] = lookup[(inByte & 0xF0) >> 4];
        outCharacters[o++] = lookup[(inByte & 0x0F)];
    }

    return [[NSString alloc] initWithCharactersNoCopy:outCharacters length:o freeWhenDone:YES];
}

