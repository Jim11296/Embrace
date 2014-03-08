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

//	PublicUtility Includes
#include "CAAutoDisposer.h"
#include "CADebugMacros.h"
#include "CAException.h"
#include "CAHALAudioSystemObject.h"
#include "CAPropertyAddress.h"

//==================================================================================================
//	CAHALAudioDevice
//==================================================================================================

CAHALAudioDevice::CAHALAudioDevice(AudioObjectID inAudioDevice)
:
	CAHALAudioObject(inAudioDevice)
{
}

CAHALAudioDevice::CAHALAudioDevice(CFStringRef inUID)
:
	CAHALAudioObject(CAHALAudioSystemObject().GetAudioDeviceForUID(inUID))
{
}

CAHALAudioDevice::~CAHALAudioDevice()
{
}

CFStringRef	CAHALAudioDevice::CopyDeviceUID() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyDeviceUID);
	return GetPropertyData_CFString(theAddress, 0, NULL);
}

bool	CAHALAudioDevice::HasModelUID() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyModelUID);
	return HasProperty(theAddress);
}

CFStringRef	CAHALAudioDevice::CopyModelUID() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyModelUID);
	return GetPropertyData_CFString(theAddress, 0, NULL);
}

CFStringRef	CAHALAudioDevice::CopyConfigurationApplicationBundleID() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyConfigurationApplication);
	return GetPropertyData_CFString(theAddress, 0, NULL);
}

CFURLRef	CAHALAudioDevice::CopyIconLocation() const
{
	CFURLRef theAnswer = NULL;
	CAPropertyAddress theAddress(kAudioDevicePropertyIcon);
	UInt32 theSize = sizeof(CFURLRef);
	GetPropertyData(theAddress, 0, NULL, theSize, &theAnswer);
	return theAnswer;
}

UInt32	CAHALAudioDevice::GetTransportType() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyTransportType);
	return GetPropertyData_UInt32(theAddress, 0, NULL);
}

bool	CAHALAudioDevice::CanBeDefaultDevice(bool inIsInput, bool inIsSystem) const
{
	CAPropertyAddress theAddress(inIsSystem ? kAudioDevicePropertyDeviceCanBeDefaultSystemDevice : kAudioDevicePropertyDeviceCanBeDefaultDevice, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	return GetPropertyData_UInt32(theAddress, 0, NULL) != 0;
}

bool	CAHALAudioDevice::HasDevicePlugInStatus() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyPlugIn);
	return HasProperty(theAddress);
}

OSStatus	CAHALAudioDevice::GetDevicePlugInStatus() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyPlugIn);
	return GetPropertyData_UInt32(theAddress, 0, NULL);
}

bool	CAHALAudioDevice::IsAlive() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyDeviceIsAlive);
	return GetPropertyData_UInt32(theAddress, 0, NULL) != 0;
}

bool	CAHALAudioDevice::IsHidden() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyIsHidden);
	return GetPropertyData_UInt32(theAddress, 0, NULL) != 0;
}

pid_t	CAHALAudioDevice::GetHogModeOwner() const
{
	pid_t theAnswer = -1;
	CAPropertyAddress theAddress(kAudioDevicePropertyHogMode);
	if(HasProperty(theAddress))
	{
		UInt32 theSize = sizeof(pid_t);
		GetPropertyData(theAddress, 0, NULL, theSize, &theAnswer);
	}
	return theAnswer;
}

bool	CAHALAudioDevice::IsHogModeSettable() const
{
	bool theAnswer = false;
	CAPropertyAddress theAddress(kAudioDevicePropertyHogMode);
	if(HasProperty(theAddress))
	{
		theAnswer = IsPropertySettable(theAddress);
	}
	return theAnswer;
}

bool	CAHALAudioDevice::TakeHogMode()
{
	CAPropertyAddress theAddress(kAudioDevicePropertyHogMode);
	pid_t thePID = getpid();
	if(HasProperty(theAddress))
	{
		SetPropertyData(theAddress, 0, NULL, sizeof(pid_t), &thePID);
	}
	return thePID == getpid();
}

void	CAHALAudioDevice::ReleaseHogMode()
{
	CAPropertyAddress theAddress(kAudioDevicePropertyHogMode);
	if(HasProperty(theAddress))
	{
		pid_t thePID = -1;
		SetPropertyData(theAddress, 0, NULL, sizeof(pid_t), &thePID);
	}
}

bool	CAHALAudioDevice::HasPreferredStereoChannels(bool inIsInput) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyPreferredChannelsForStereo, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	return HasProperty(theAddress);
}

void	CAHALAudioDevice::GetPreferredStereoChannels(bool inIsInput, UInt32& outLeft, UInt32& outRight) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyPreferredChannelsForStereo, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	UInt32 theStereoPair[2] = { 0, 0 };
	UInt32 theSize = 2 * sizeof(UInt32);
	GetPropertyData(theAddress, 0, NULL, theSize, theStereoPair);
	outLeft = theStereoPair[0];
	outRight = theStereoPair[1];
}

void	CAHALAudioDevice::SetPreferredStereoChannels(bool inIsInput, UInt32 inLeft, UInt32 inRight)
{
	CAPropertyAddress theAddress(kAudioDevicePropertyPreferredChannelsForStereo, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	UInt32 theStereoPair[2] = { inLeft, inRight };
	SetPropertyData(theAddress, 0, NULL, 2 * sizeof(UInt32), theStereoPair);
}

bool	CAHALAudioDevice::HasPreferredChannelLayout(bool inIsInput) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyPreferredChannelLayout, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	return HasProperty(theAddress);
}

void	CAHALAudioDevice::GetPreferredChannelLayout(bool inIsInput, AudioChannelLayout& outChannelLayout) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyPreferredChannelLayout, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	UInt32 theSize = OffsetOf32(AudioChannelLayout, mChannelDescriptions) + GetTotalNumberChannels(inIsInput) * SizeOf32(AudioChannelDescription);
	GetPropertyData(theAddress, 0, NULL, theSize, &outChannelLayout);
}

void	CAHALAudioDevice::SetPreferredStereoChannels(bool inIsInput, AudioChannelLayout& inChannelLayout)
{
	CAPropertyAddress theAddress(kAudioDevicePropertyPreferredChannelLayout, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	UInt32 theSize = OffsetOf32(AudioChannelLayout, mChannelDescriptions) + GetTotalNumberChannels(inIsInput) * SizeOf32(AudioChannelDescription);
	SetPropertyData(theAddress, 0, NULL, theSize, &inChannelLayout);
}

UInt32	CAHALAudioDevice::GetNumberRelatedAudioDevices() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyRelatedDevices);
	UInt32 theAnswer = 0;
	if(HasProperty(theAddress))
	{
		theAnswer = GetPropertyDataSize(theAddress, 0, NULL);
		theAnswer /= SizeOf32(AudioObjectID);
	}
	return theAnswer;
}

void	CAHALAudioDevice::GetRelatedAudioDevices(UInt32& ioNumberRelatedDevices, AudioObjectID* outRelatedDevices) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyRelatedDevices);
	if(HasProperty(theAddress))
	{
		UInt32 theSize = ioNumberRelatedDevices * SizeOf32(AudioObjectID);
		GetPropertyData(theAddress, 0, NULL, theSize, outRelatedDevices);
		ioNumberRelatedDevices = theSize / SizeOf32(AudioObjectID);
	}
	else
	{
		UInt32 theSize = ioNumberRelatedDevices * SizeOf32(AudioObjectID);
		memset(outRelatedDevices, 0, theSize);
		ioNumberRelatedDevices = 0;
	}
}

AudioObjectID	CAHALAudioDevice::GetRelatedAudioDeviceByIndex(UInt32 inIndex) const
{
	AudioObjectID theAnswer = kAudioObjectUnknown;
	UInt32 theNumberRelatedDevices = GetNumberRelatedAudioDevices();
	if((theNumberRelatedDevices > 0) && (inIndex < theNumberRelatedDevices))
	{
		CAAutoArrayDelete<AudioObjectID> theRelatedDeviceList(theNumberRelatedDevices);
		GetRelatedAudioDevices(theNumberRelatedDevices, theRelatedDeviceList);
		if((theNumberRelatedDevices > 0) && (inIndex < theNumberRelatedDevices))
		{
			theAnswer = theRelatedDeviceList[inIndex];
		}
	}
	return theAnswer;
}

UInt32	CAHALAudioDevice::GetNumberStreams(bool inIsInput) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyStreams, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	UInt32 theAnswer = GetPropertyDataSize(theAddress, 0, NULL);
	theAnswer /= SizeOf32(AudioObjectID);
	return theAnswer;
}

void	CAHALAudioDevice::GetStreams(bool inIsInput, UInt32& ioNumberStreams, AudioObjectID* outStreamList) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyStreams, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	UInt32 theSize = ioNumberStreams * SizeOf32(AudioObjectID);
	GetPropertyData(theAddress, 0, NULL, theSize, outStreamList);
	ioNumberStreams = theSize / SizeOf32(AudioObjectID);
}

AudioObjectID	CAHALAudioDevice::GetStreamByIndex(bool inIsInput, UInt32 inIndex) const
{
	AudioObjectID theAnswer = kAudioObjectUnknown;
	UInt32 theNumberStreams = GetNumberStreams(inIsInput);
	if((theNumberStreams > 0) && (inIndex < theNumberStreams))
	{
		CAAutoArrayDelete<AudioObjectID> theStreamList(theNumberStreams);
		GetStreams(inIsInput, theNumberStreams, theStreamList);
		if((theNumberStreams > 0) && (inIndex < theNumberStreams))
		{
			theAnswer = theStreamList[inIndex];
		}
	}
	return theAnswer;
}

UInt32	CAHALAudioDevice::GetTotalNumberChannels(bool inIsInput) const
{
	UInt32 theAnswer = 0;
	CAPropertyAddress theAddress(kAudioDevicePropertyStreamConfiguration, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	UInt32 theSize = GetPropertyDataSize(theAddress, 0, NULL);
	CAAutoFree<AudioBufferList> theBufferList(theSize);
	GetPropertyData(theAddress, 0, NULL, theSize, theBufferList);
	for(UInt32 theIndex = 0; theIndex < theBufferList->mNumberBuffers; ++theIndex)
	{
		theAnswer += theBufferList->mBuffers[theIndex].mNumberChannels;
	}
	return theAnswer;
}

bool	CAHALAudioDevice::IsRunning() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyDeviceIsRunning);
	UInt32 theAnswer = GetPropertyData_UInt32(theAddress, 0, NULL);
	return theAnswer != 0;
}

bool	CAHALAudioDevice::IsRunningSomewhere() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyDeviceIsRunningSomewhere);
	UInt32 theAnswer = 0;
	if(HasProperty(theAddress))
	{
		theAnswer = GetPropertyData_UInt32(theAddress, 0, NULL);
	}
	return theAnswer != 0;
}

UInt32	CAHALAudioDevice::GetLatency(bool inIsInput) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyLatency, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	return GetPropertyData_UInt32(theAddress, 0, NULL);
}

UInt32	CAHALAudioDevice::GetSafetyOffset(bool inIsInput) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertySafetyOffset, inIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput);
	return GetPropertyData_UInt32(theAddress, 0, NULL);
}

bool	CAHALAudioDevice::HasClockDomain() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyClockDomain);
	return HasProperty(theAddress);
}

UInt32	CAHALAudioDevice::GetClockDomain() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyClockDomain);
	return GetPropertyData_UInt32(theAddress, 0, NULL);
}

Float64	CAHALAudioDevice::GetActualSampleRate() const
{
	Float64 theAnswer = 0;
	CAPropertyAddress theAddress(kAudioDevicePropertyActualSampleRate);
	if(HasProperty(theAddress))
	{
		UInt32 theSize = sizeof(Float64);
		GetPropertyData(theAddress, 0, NULL, theSize, &theAnswer);
	}
	else
	{
		theAnswer = GetNominalSampleRate();
	}
	return theAnswer;
}

Float64	CAHALAudioDevice::GetNominalSampleRate() const
{
	Float64 theAnswer = 0;
	CAPropertyAddress theAddress(kAudioDevicePropertyNominalSampleRate);
	UInt32 theSize = sizeof(Float64);
	GetPropertyData(theAddress, 0, NULL, theSize, &theAnswer);
	return theAnswer;
}

void	CAHALAudioDevice::SetNominalSampleRate(Float64 inSampleRate)
{
	CAPropertyAddress theAddress(kAudioDevicePropertyNominalSampleRate);
	SetPropertyData(theAddress, 0, NULL, sizeof(Float64), &inSampleRate);
}

UInt32	CAHALAudioDevice::GetNumberAvailableNominalSampleRateRanges() const
{
	UInt32 theAnswer = 0;
	CAPropertyAddress theAddress(kAudioDevicePropertyAvailableNominalSampleRates);
	if(HasProperty(theAddress))
	{
		UInt32 theSize = GetPropertyDataSize(theAddress, 0, NULL);
		theAnswer = theSize / SizeOf32(AudioValueRange);
	}
	return theAnswer;
}

void	CAHALAudioDevice::GetAvailableNominalSampleRateRanges(UInt32& ioNumberRanges, AudioValueRange* outRanges) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyAvailableNominalSampleRates);
	if(HasProperty(theAddress))
	{
		UInt32 theSize = ioNumberRanges * SizeOf32(AudioValueRange);
		GetPropertyData(theAddress, 0, NULL, theSize, outRanges);
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
	ThrowIf(inIndex >= theNumberRanges, CAException(kAudioHardwareIllegalOperationError), "CAHALAudioDevice::GetAvailableNominalSampleRateRangeByIndex: index out of range");
	CAAutoArrayDelete<AudioValueRange> theRanges(theNumberRanges);
	GetAvailableNominalSampleRateRanges(theNumberRanges, theRanges);
	outMinimum = theRanges[inIndex].mMinimum;
	outMaximum = theRanges[inIndex].mMaximum;
}

bool	CAHALAudioDevice::IsValidNominalSampleRate(Float64 inSampleRate) const
{
	bool theAnswer = false;
	UInt32 theNumberRanges = GetNumberAvailableNominalSampleRateRanges();
	CAAutoArrayDelete<AudioValueRange> theRanges(theNumberRanges);
	GetAvailableNominalSampleRateRanges(theNumberRanges, theRanges);
	for(UInt32 theIndex = 0; !theAnswer && (theIndex < theNumberRanges); ++theIndex)
	{
		theAnswer = (inSampleRate >= theRanges[theIndex].mMinimum) && (inSampleRate <= theRanges[theIndex].mMinimum);
	}
	return theAnswer;
}

bool	CAHALAudioDevice::IsIOBufferSizeSettable() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyBufferFrameSize);
	return IsPropertySettable(theAddress);
}

UInt32	CAHALAudioDevice::GetIOBufferSize() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyBufferFrameSize);
	return GetPropertyData_UInt32(theAddress, 0, NULL);
}

void	CAHALAudioDevice::SetIOBufferSize(UInt32 inBufferSize)
{
	CAPropertyAddress theAddress(kAudioDevicePropertyBufferFrameSize);
	SetPropertyData(theAddress, 0, NULL, sizeof(UInt32), &inBufferSize);
}

bool	CAHALAudioDevice::UsesVariableIOBufferSizes() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyUsesVariableBufferFrameSizes);
	return HasProperty(theAddress);
}

UInt32	CAHALAudioDevice::GetMaximumVariableIOBufferSize() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyUsesVariableBufferFrameSizes);
	return GetPropertyData_UInt32(theAddress, 0, NULL);
}

bool	CAHALAudioDevice::HasIOBufferSizeRange() const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyBufferFrameSizeRange);
	return HasProperty(theAddress);
}

void	CAHALAudioDevice::GetIOBufferSizeRange(UInt32& outMinimum, UInt32& outMaximum) const
{
	AudioValueRange theAnswer = { 0, 0 };
	CAPropertyAddress theAddress(kAudioDevicePropertyBufferFrameSizeRange);
	UInt32 theSize = sizeof(AudioValueRange);
	GetPropertyData(theAddress, 0, NULL, theSize, &theAnswer);
	outMinimum = static_cast<UInt32>(theAnswer.mMinimum);
	outMaximum = static_cast<UInt32>(theAnswer.mMaximum);
}

bool	CAHALAudioDevice::HasVolumeControl(AudioObjectPropertyScope inScope, UInt32 inChannel) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyVolumeScalar, inScope, inChannel);
	return HasProperty(theAddress);
}

bool	CAHALAudioDevice::VolumeControlIsSettable(AudioObjectPropertyScope inScope, UInt32 inChannel) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyVolumeScalar, inScope, inChannel);
	return IsPropertySettable(theAddress);
}

Float32	CAHALAudioDevice::GetVolumeControlScalarValue(AudioObjectPropertyScope inScope, UInt32 inChannel) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyVolumeScalar, inScope, inChannel);
	Float32 theValue = 0.0f;
	UInt32 theSize = sizeof(Float32);
	GetPropertyData(theAddress, 0, NULL, theSize, &theValue);
	return theValue;
}

void	CAHALAudioDevice::SetVolumeControlScalarValue(AudioObjectPropertyScope inScope, UInt32 inChannel, Float32 inValue)
{
	CAPropertyAddress theAddress(kAudioDevicePropertyVolumeScalar, inScope, inChannel);
	SetPropertyData(theAddress, 0, NULL, sizeof(Float32), &inValue);
}



bool	CAHALAudioDevice::HasMuteControl(AudioObjectPropertyScope inScope, UInt32 inChannel) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyMute, inScope, inChannel);
	return HasProperty(theAddress);
}

bool	CAHALAudioDevice::MuteControlIsSettable(AudioObjectPropertyScope inScope, UInt32 inChannel) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyMute, inScope, inChannel);
	return IsPropertySettable(theAddress);
}

bool	CAHALAudioDevice::GetMuteControlValue(AudioObjectPropertyScope inScope, UInt32 inChannel) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyMute, inScope, inChannel);
	UInt32 theValue = 0;
	UInt32 theSize = sizeof(UInt32);
	GetPropertyData(theAddress, 0, NULL, theSize, &theValue);
	return theValue != 0;
}

void	CAHALAudioDevice::SetMuteControlValue(AudioObjectPropertyScope inScope, UInt32 inChannel, bool inValue)
{
	CAPropertyAddress theAddress(kAudioDevicePropertyMute, inScope, inChannel);
	UInt32 theValue = (inValue ? 1 : 0);
	UInt32 theSize = sizeof(UInt32);
	SetPropertyData(theAddress, 0, NULL, theSize, &theValue);
}

bool	CAHALAudioDevice::HasStereoPanControl(AudioObjectPropertyScope inScope, UInt32 inChannel) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyStereoPan, inScope, inChannel);
	return HasProperty(theAddress);
}

bool	CAHALAudioDevice::StereoPanControlIsSettable(AudioObjectPropertyScope inScope, UInt32 inChannel) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyStereoPan, inScope, inChannel);
	return IsPropertySettable(theAddress);
}

Float32	CAHALAudioDevice::GetStereoPanControlValue(AudioObjectPropertyScope inScope, UInt32 inChannel) const
{
	CAPropertyAddress theAddress(kAudioDevicePropertyStereoPan, inScope, inChannel);
	Float32 theValue = 0.0f;
	UInt32 theSize = sizeof(Float32);
	GetPropertyData(theAddress, 0, NULL, theSize, &theValue);
	return theValue;
}

void	CAHALAudioDevice::SetStereoPanControlValue(AudioObjectPropertyScope inScope, UInt32 inChannel, Float32 inValue)
{
	CAPropertyAddress theAddress(kAudioDevicePropertyStereoPan, inScope, inChannel);
	UInt32 theSize = sizeof(Float32);
	SetPropertyData(theAddress, 0, NULL, theSize, &inValue);
}
