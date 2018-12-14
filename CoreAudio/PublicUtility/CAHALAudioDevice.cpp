/*
     File: CAHALAudioDevice.cpp 
 Abstract:  CAHALAudioDevice.h  
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
//==================================================================================================
//	Includes
//==================================================================================================

//	Self Include
#include "CAHALAudioDevice.h"

#include "CAException.h"

//==================================================================================================
//	CAHALAudioDevice
//==================================================================================================


static const AudioObjectPropertyScope sScopeGlobal = kAudioObjectPropertyScopeGlobal;
static const AudioObjectPropertyScope sScopeOutput = kAudioDevicePropertyScopeOutput;

static const AudioObjectPropertyAddress sAddressDeviceForUID =
    { kAudioHardwarePropertyDeviceForUID, sScopeGlobal, 0 };

static const AudioObjectPropertyAddress sAddressModelUID =
    { kAudioDevicePropertyModelUID, sScopeGlobal, 0 };

static const AudioObjectPropertyAddress sAddressTransportType =
    { kAudioDevicePropertyTransportType, sScopeGlobal, 0 };
    
static const AudioObjectPropertyAddress sAddressNominalSampleRate =
    { kAudioDevicePropertyNominalSampleRate, sScopeGlobal, 0 };

static const AudioObjectPropertyAddress sAddressAvailableNominalSampleRates =
    { kAudioDevicePropertyAvailableNominalSampleRates, sScopeGlobal, 0 };

static const AudioObjectPropertyAddress sAddressHogMode =
    { kAudioDevicePropertyHogMode, sScopeGlobal, 0 };
    
static const AudioObjectPropertyAddress sAddressBufferFrameSize =
    { kAudioDevicePropertyBufferFrameSize , sScopeGlobal, 0 };

static const AudioObjectPropertyAddress sAddressBufferFrameSizeRange =
    { kAudioDevicePropertyBufferFrameSizeRange, sScopeGlobal, 0 };



CAHALAudioDevice::CAHALAudioDevice(AudioObjectID inAudioDevice)
:
    mObjectID(inAudioDevice)
{
}



static AudioObjectID sAudioDeviceWithUID(CFStringRef inUID)
{
    AudioObjectID theAnswer = kAudioObjectUnknown;
    AudioValueTranslation theValue = { &inUID, sizeof(CFStringRef), &theAnswer, sizeof(AudioObjectID) };
    AudioObjectPropertyAddress theAddress = sAddressDeviceForUID;
    UInt32 theSize = sizeof(AudioValueTranslation);

    OSStatus theError = AudioObjectGetPropertyData(kAudioObjectSystemObject, &theAddress, 0, NULL, &theSize, &theValue);
    if (theError) throw CAException(theError);

    return theAnswer;
}



CAHALAudioDevice::CAHALAudioDevice(CFStringRef inUID)
:
	CAHALAudioDevice(sAudioDeviceWithUID(inUID))
{
}

CAHALAudioDevice::~CAHALAudioDevice()
{
}


bool CAHALAudioDevice::HasModelUID() const
{
	return HasProperty(sAddressModelUID);
}


CFStringRef	CAHALAudioDevice::CopyModelUID() const
{
	return GetPropertyData_CFString(sAddressModelUID);
}


UInt32 CAHALAudioDevice::GetTransportType() const
{
	return GetPropertyData_UInt32(sAddressTransportType);
}


pid_t CAHALAudioDevice::GetHogModeOwner() const
{
	pid_t theAnswer = -1;

	if (HasProperty(sAddressHogMode)) {
		UInt32 theSize = sizeof(pid_t);
		GetPropertyData(sAddressHogMode, theSize, &theAnswer);
	}

	return theAnswer;
}

bool CAHALAudioDevice::IsHogModeSettable() const
{
	bool theAnswer = false;
	if (HasProperty(sAddressHogMode)) {
        theAnswer = IsPropertySettable(sAddressHogMode);
	}
	return theAnswer;
}


bool CAHALAudioDevice::TakeHogMode()
{
	pid_t thePID = getpid();
	if (HasProperty(sAddressHogMode)) {
		SetPropertyData(sAddressHogMode, sizeof(pid_t), &thePID);
	}

	return thePID == getpid();
}

void CAHALAudioDevice::ReleaseHogMode()
{
	if (HasProperty(sAddressHogMode)) {
		pid_t thePID = -1;
		SetPropertyData(sAddressHogMode, sizeof(pid_t), &thePID);
	}
}


UInt32	CAHALAudioDevice::GetTotalNumberChannels() const
{
	UInt32 theAnswer = 0;
	AudioObjectPropertyAddress theAddress= { kAudioDevicePropertyStreamConfiguration, sScopeOutput, 0 };
	UInt32 theSize = GetPropertyDataSize(theAddress);
 
    AudioBufferList *theBufferList = (AudioBufferList *)alloca(theSize);
    GetPropertyData(theAddress, theSize, theBufferList);

	for(UInt32 theIndex = 0; theIndex < theBufferList->mNumberBuffers; ++theIndex)
	{
		theAnswer += theBufferList->mBuffers[theIndex].mNumberChannels;
	}
	return theAnswer;
}



Float64	CAHALAudioDevice::GetNominalSampleRate() const
{
	Float64 theAnswer = 0;
	AudioObjectPropertyAddress theAddress = sAddressNominalSampleRate;
 	UInt32 theSize = sizeof(Float64);
	GetPropertyData(theAddress, theSize, &theAnswer);
	return theAnswer;
}

void	CAHALAudioDevice::SetNominalSampleRate(Float64 inSampleRate)
{
	AudioObjectPropertyAddress theAddress = sAddressNominalSampleRate;
 	SetPropertyData(theAddress, sizeof(Float64), &inSampleRate);
}

UInt32	CAHALAudioDevice::GetNumberAvailableNominalSampleRateRanges() const
{
	UInt32 theAnswer = 0;
	AudioObjectPropertyAddress theAddress = sAddressAvailableNominalSampleRates;
 	if(HasProperty(theAddress))
	{
		UInt32 theSize = GetPropertyDataSize(theAddress);
		theAnswer = theSize / SizeOf32(AudioValueRange);
	}
	return theAnswer;
}

void	CAHALAudioDevice::GetAvailableNominalSampleRateRanges(UInt32& ioNumberRanges, AudioValueRange* outRanges) const
{
	AudioObjectPropertyAddress theAddress = sAddressAvailableNominalSampleRates;
 	if(HasProperty(theAddress))
	{
		UInt32 theSize = ioNumberRanges * SizeOf32(AudioValueRange);
		GetPropertyData(theAddress, theSize, outRanges);
		ioNumberRanges = theSize / SizeOf32(AudioValueRange);
	}
	else
	{
		ioNumberRanges = 0;
	}
}

void	CAHALAudioDevice::GetAvailableNominalSampleRateRangeByIndex(UInt32 inIndex, Float64& outMinimum, Float64& outMaximum) const
{
	UInt32 theNumberRanges = GetNumberAvailableNominalSampleRateRanges();
	
    if (inIndex >= theNumberRanges) {
        throw CAException(kAudioHardwareIllegalOperationError);
    }

	AudioValueRange theRanges[theNumberRanges];
 	GetAvailableNominalSampleRateRanges(theNumberRanges, theRanges);

	outMinimum = theRanges[inIndex].mMinimum;
	outMaximum = theRanges[inIndex].mMaximum;
}

bool	CAHALAudioDevice::IsValidNominalSampleRate(Float64 inSampleRate) const
{
	bool theAnswer = false;
	UInt32 theNumberRanges = GetNumberAvailableNominalSampleRateRanges();

	AudioValueRange theRanges[theNumberRanges];
	GetAvailableNominalSampleRateRanges(theNumberRanges, theRanges);

	for(UInt32 theIndex = 0; !theAnswer && (theIndex < theNumberRanges); ++theIndex)
	{
		theAnswer = (inSampleRate >= theRanges[theIndex].mMinimum) && (inSampleRate <= theRanges[theIndex].mMinimum);
	}
	return theAnswer;
}

bool	CAHALAudioDevice::IsIOBufferSizeSettable() const
{
	return IsPropertySettable(sAddressBufferFrameSize);
}

UInt32	CAHALAudioDevice::GetIOBufferSize() const
{
	return GetPropertyData_UInt32(sAddressBufferFrameSize);
}

void	CAHALAudioDevice::SetIOBufferSize(UInt32 inBufferSize)
{
	SetPropertyData(sAddressBufferFrameSize, sizeof(UInt32), &inBufferSize);
}


bool	CAHALAudioDevice::HasIOBufferSizeRange() const
{
	return HasProperty(sAddressBufferFrameSizeRange);
}

void	CAHALAudioDevice::GetIOBufferSizeRange(UInt32& outMinimum, UInt32& outMaximum) const
{
	AudioValueRange theAnswer = { 0, 0 };
	AudioObjectPropertyAddress theAddress = sAddressBufferFrameSizeRange;
	UInt32 theSize = sizeof(AudioValueRange);
	GetPropertyData(theAddress, theSize, &theAnswer);
	outMinimum = static_cast<UInt32>(theAnswer.mMinimum);
	outMaximum = static_cast<UInt32>(theAnswer.mMaximum);
}

bool	CAHALAudioDevice::HasSettableVolumeControl(UInt32 inChannel) const
{
	AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyVolumeScalar, sScopeOutput, inChannel };
	return HasProperty(theAddress) && IsPropertySettable(theAddress);
}

Float32	CAHALAudioDevice::GetVolumeControlScalarValue(UInt32 inChannel) const
{
	AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyVolumeScalar, sScopeOutput, inChannel };
	Float32 theValue = 0.0f;
	UInt32 theSize = sizeof(Float32);
	GetPropertyData(theAddress, theSize, &theValue);
	return theValue;
}

void	CAHALAudioDevice::SetVolumeControlScalarValue(UInt32 inChannel, Float32 inValue)
{
	AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyVolumeScalar, sScopeOutput, inChannel };
	SetPropertyData(theAddress, sizeof(Float32), &inValue);
}



bool	CAHALAudioDevice::HasSettableMuteControl(UInt32 inChannel) const
{
	AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyMute, sScopeOutput, inChannel };
	return HasProperty(theAddress) && IsPropertySettable(theAddress);
}

bool	CAHALAudioDevice::GetMuteControlValue(UInt32 inChannel) const
{
	AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyMute, sScopeOutput, inChannel };
	UInt32 theValue = 0;
	UInt32 theSize = sizeof(UInt32);
	GetPropertyData(theAddress, theSize, &theValue);
	return theValue != 0;
}

void	CAHALAudioDevice::SetMuteControlValue(UInt32 inChannel, bool inValue)
{
	AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyMute, sScopeOutput, inChannel };
	UInt32 theValue = (inValue ? 1 : 0);
	UInt32 theSize = sizeof(UInt32);
	SetPropertyData(theAddress, theSize, &theValue);
}

bool	CAHALAudioDevice::HasSettableStereoPanControl(UInt32 inChannel) const
{
	AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyStereoPan, sScopeOutput, inChannel };
	return HasProperty(theAddress) && IsPropertySettable(theAddress);
}

Float32	CAHALAudioDevice::GetStereoPanControlValue(UInt32 inChannel) const
{
	AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyStereoPan, sScopeOutput, inChannel };
	Float32 theValue = 0.0f;
	UInt32 theSize = sizeof(Float32);
	GetPropertyData(theAddress, theSize, &theValue);
	return theValue;
}

void	CAHALAudioDevice::SetStereoPanControlValue(UInt32 inChannel, Float32 inValue)
{
	AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyStereoPan, sScopeOutput, inChannel };
	UInt32 theSize = sizeof(Float32);
	SetPropertyData(theAddress, theSize, &inValue);
}



AudioObjectID    CAHALAudioDevice::GetObjectID() const
{
    return mObjectID;
}

CFStringRef    CAHALAudioDevice::CopyName() const
{
    CFStringRef theAnswer = NULL;
    
    AudioObjectPropertyAddress address = { kAudioObjectPropertyName, sScopeGlobal, 0 };

    //    make sure the property exists
    if (HasProperty(address)) {
        //    get the property data
        UInt32 theSize = sizeof(CFStringRef);
        GetPropertyData(address, theSize, &theAnswer);
    }
    
    return theAnswer;
}

CFStringRef    CAHALAudioDevice::CopyManufacturer() const
{
    CFStringRef theAnswer = NULL;
    
    //    set up the property address
    AudioObjectPropertyAddress address = { kAudioObjectPropertyManufacturer, sScopeGlobal, 0 };

    //    make sure the property exists
    if (HasProperty(address)) {
        UInt32 theSize = sizeof(CFStringRef);
        GetPropertyData(address, theSize, &theAnswer);
    }
    
    return theAnswer;
}


bool CAHALAudioDevice::HasProperty(const AudioObjectPropertyAddress& inAddress) const
{
    return AudioObjectHasProperty(mObjectID, &inAddress);
}

bool CAHALAudioDevice::IsPropertySettable(const AudioObjectPropertyAddress& inAddress) const
{
    Boolean isSettable = false;
    OSStatus theError = AudioObjectIsPropertySettable(mObjectID, &inAddress, &isSettable);
    if (theError) throw CAException(theError);
     return isSettable != 0;
}

UInt32    CAHALAudioDevice::GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress) const
{
    UInt32 theDataSize = 0;
    OSStatus theError = AudioObjectGetPropertyDataSize(mObjectID, &inAddress, 0, NULL, &theDataSize);
    if (theError) throw CAException(theError);
    return theDataSize;
}

void    CAHALAudioDevice::GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32& ioDataSize, void* outData) const
{
    OSStatus theError = AudioObjectGetPropertyData(mObjectID, &inAddress, 0, NULL, &ioDataSize, outData);
    if (theError) throw CAException(theError);
}


void    CAHALAudioDevice::SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inDataSize, const void* inData)
{
    OSStatus theError = AudioObjectSetPropertyData(mObjectID, &inAddress, 0, NULL, inDataSize, inData);
    if (theError) throw CAException(theError);
}
