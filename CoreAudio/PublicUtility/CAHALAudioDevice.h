/*
     File: CAHALAudioDevice.h 
 Abstract:  Part of CoreAudio Utility Classes  
  Version: 1.0.4 
  
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple 
 Inc. ("Apple") in consideration of your agreement to the following 
 terms, and your use, installation, modification or redistribution of 
 this Apple software constitutes acceptance of these terms.  If you do 
 not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software. 
  
 In consideration of your agreement to abide by the following terms, and 
 subject to these terms, Apple grants you a personal, non-exclusive 
 license, under Apple's copyrights in this original Apple software (the 
 "Apple Software"), to use, reproduce, modify and redistribute the Apple 
 Software, with or without modifications, in source and/or binary forms; 
 provided that if you redistribute the Apple Software in its entirety and 
 without modifications, you must retain this notice and the following 
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc. may 
 be used to endorse or promote products derived from the Apple Software 
 without specific prior written permission from Apple.  Except as 
 expressly stated in this notice, no other rights or licenses, express or 
 implied, are granted by Apple herein, including but not limited to any 
 patent rights that may be infringed by your derivative works or by other 
 works in which the Apple Software may be incorporated. 
  
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE 
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION 
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS 
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND 
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS. 
  
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL 
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, 
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED 
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), 
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE 
 POSSIBILITY OF SUCH DAMAGE. 
  
 Copyright (C) 2013 Apple Inc. All Rights Reserved. 
  
*/
#if !defined(__CAHALAudioDevice_h__)
#define __CAHALAudioDevice_h__


//    This is a macro that does a sizeof and casts the result to a UInt32. This is useful for all the
//    places where -wshorten64-32 catches assigning a sizeof expression to a UInt32.
//    For want of a better place to park this, we'll park it here.
#define    SizeOf32(X)    ((UInt32)sizeof(X))

//    This is a macro that does a offsetof and casts the result to a UInt32. This is useful for all the
//    places where -wshorten64-32 catches assigning an offsetof expression to a UInt32.
//    For want of a better place to park this, we'll park it here.
#define    OffsetOf32(X, Y)    ((UInt32)offsetof(X, Y))

//    This macro casts the expression to a UInt32. It is called out specially to allow us to track casts
//    that have been added purely to avert -wshorten64-32 warnings on 64 bit platforms.
//    For want of a better place to park this, we'll park it here.
#define    ToUInt32(X)    ((UInt32)(X))

//    System Includes
#if !defined(__COREAUDIO_USE_FLAT_INCLUDES__)
    #include <CoreAudio/CoreAudio.h>
    #include <CoreFoundation/CoreFoundation.h>
#else
    #include <CoreAudio.h>
    #include <CoreFoundation.h>
#endif

class CAHALAudioDevice
{
private:
    AudioObjectID                mObjectID;

//	Construction/Destruction
public:
						CAHALAudioDevice(AudioObjectID inAudioDevice);
						CAHALAudioDevice(CFStringRef inUID);
	virtual				~CAHALAudioDevice();

//	General Stuff
public:
    AudioObjectID                GetObjectID() const;
    CFStringRef                    CopyName() const;
    CFStringRef                    CopyManufacturer() const;

	bool				HasModelUID() const;
	CFStringRef			CopyModelUID() const;
	UInt32				GetTransportType() const;
	pid_t				GetHogModeOwner() const;
	bool				IsHogModeSettable() const;
	bool				TakeHogMode();
	void				ReleaseHogMode();

//	Stream Stuff
public:
	UInt32				GetTotalNumberChannels() const;
	
//	IO Stuff
public:
	Float64				GetNominalSampleRate() const;
	void				SetNominalSampleRate(Float64 inSampleRate);
	UInt32				GetNumberAvailableNominalSampleRateRanges() const;
	void				GetAvailableNominalSampleRateRanges(UInt32& ioNumberRanges, AudioValueRange* outRanges) const;
	void				GetAvailableNominalSampleRateRangeByIndex(UInt32 inIndex, Float64& outMinimum, Float64& outMaximum) const;
	bool				IsValidNominalSampleRate(Float64 inSampleRate) const;
	bool				IsIOBufferSizeSettable() const;
	UInt32				GetIOBufferSize() const;
	void				SetIOBufferSize(UInt32 inBufferSize);
	bool				HasIOBufferSizeRange() const;
	void				GetIOBufferSizeRange(UInt32& outMinimum, UInt32& outMaximum) const;

//	Controls
public:
	bool				HasSettableVolumeControl(UInt32 inChannel) const;
    Float32             GetVolumeControlScalarValue(UInt32 inChannel) const;
	void				SetVolumeControlScalarValue(UInt32 inChannel, Float32 inValue);

	bool				HasSettableMuteControl(UInt32 inChannel) const;
    bool                GetMuteControlValue(UInt32 inChannel) const;
	void				SetMuteControlValue(UInt32 inChannel, bool inValue);

	bool				HasSettableStereoPanControl(UInt32 inChannel) const;
    Float32             GetStereoPanControlValue(UInt32 inChannel) const;
	void				SetStereoPanControlValue(UInt32 inChannel, Float32 inValue);

private:
    bool   HasProperty(const AudioObjectPropertyAddress& inAddress) const;
    bool   IsPropertySettable(const AudioObjectPropertyAddress& inAddress) const;
    UInt32 GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress) const;
    
    void   GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32& ioDataSize, void* outData) const;
    void   SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inDataSize, const void* inData);
    
    UInt32 GetPropertyData_UInt32(const AudioObjectPropertyAddress& inAddress) const                                        { UInt32 theAnswer = 0; UInt32 theDataSize = SizeOf32(UInt32); GetPropertyData(inAddress, theDataSize, &theAnswer); return theAnswer; }

    CFStringRef GetPropertyData_CFString(const AudioObjectPropertyAddress& inAddress) const                                        { CFStringRef theAnswer = NULL; UInt32 theDataSize = SizeOf32(CFStringRef); GetPropertyData(inAddress, theDataSize, &theAnswer); return theAnswer; }


};

#endif
