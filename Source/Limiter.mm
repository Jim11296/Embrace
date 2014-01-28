//
//  Limiter.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-27.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Limiter.h"
#import "AUEffectBase.h"
#import "CARingBuffer.h"
#import "AELimiter.h"
#import "AEFloatConverter.h"
#import <Accelerate/Accelerate.h>

const int kScratchBufferLength = 8192;

const int kBufferSize = 88200; /* Bytes per channel */
const UInt32 kNoValue = INT_MAX;

static inline int min(int a, int b) { return a>b ? b : a; }


typedef NS_ENUM(NSInteger, LimiterState) {
    kStateIdle,
    kStateAttacking,
    kStateHolding,
    kStateDecaying
};


typedef struct {
    float value;
    int index;
} element_t;



class EmergencyLimiter : public AUEffectBase {
public:
    EmergencyLimiter(AudioUnit component);

	virtual OSStatus Initialize();
	virtual void Cleanup();


    virtual OSStatus ProcessBufferLists(AudioUnitRenderActionFlags &ioActionFlags, const AudioBufferList &inBuffer, AudioBufferList &outBuffer, UInt32 inFramesToProcess);
	virtual	OSStatus ChangeStreamFormat(AudioUnitScope inScope, AudioUnitElement inElement, const CAStreamBasicDescription &inPrevFormat, const CAStreamBasicDescription &inNewFormat);

protected:
    inline void advanceTime(UInt32 frames);
    void _dequeue(float** buffers, UInt32 *ioLength, AudioTimeStamp *timestamp);
    element_t findMaxValueInRange(AudioBufferList *dequeuedBufferList, int dequeuedBufferListOffset, NSRange range);
    element_t findNextTriggerValueInRange(AudioBufferList *dequeuedBufferList, int dequeuedBufferListOffset, NSRange range);

private:
    CARingBuffer mBuffer;
    
    AELimiter *mLimiter;
    AEFloatConverter *mFloatConverter;
    float **mScratchBuffer;
    NSInteger mScratchBufferChannelCount;
    UInt32 mAttack;
    UInt64 mSampleTime;


    float            _gain;
    LimiterState     _state;
    int              _framesSinceLastTrigger;
    int              _framesToNextTrigger;
    float            _triggerValue;
    AudioStreamBasicDescription _audioDescription;

    UInt32 _hold;
    UInt32 _attack;
    UInt32 _decay;
    float  _level;
};




/*
- (id)initWithNumberOfChannels:(NSInteger)numberOfChannels sampleRate:(Float32)sampleRate {
    if ( !(self = [super init]) ) return nil;
    
    TPCircularBufferInit(&_buffer, kBufferSize*numberOfChannels);
    self.hold = 22050;
    self.decay = 44100;
    self.attack = 2048;
    _level = 0.2;
    _gain = 1.0;
    _framesSinceLastTrigger = kNoValue;
    _framesToNextTrigger = kNoValue;
    
    _audioDescription.mFormatID          = kAudioFormatLinearPCM;
    _audioDescription.mFormatFlags       = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    _audioDescription.mChannelsPerFrame  = numberOfChannels;
    _audioDescription.mBytesPerPacket    = sizeof(float);
    _audioDescription.mFramesPerPacket   = 1;
    _audioDescription.mBytesPerFrame     = sizeof(float);
    _audioDescription.mBitsPerChannel    = 8 * sizeof(float);
    _audioDescription.mSampleRate        = sampleRate;

    return self;
}
*/


AudioComponent sLimiterComponent;



void LimiterGetComponentDescription(AudioComponentDescription *outDesc)
{
    if (!sLimiterComponent) {
        sLimiterComponent = AUBaseFactory<EmergencyLimiter>::Register(kAudioUnitType_Effect, 'EmLm', 'EmBr', CFSTR("Embrace Emergency Limiter"), 100, kAudioComponentFlag_Unsearchable|kAudioComponentFlag_SandboxSafe);
    }
   

    AudioComponentGetDescription(sLimiterComponent, outDesc);
}



EmergencyLimiter::EmergencyLimiter(AudioUnit component) :
    AUEffectBase(component, false)
{

}

OSStatus EmergencyLimiter::Initialize()
{
//    AudioStreamBasicDescription clientFormat = GetOutput(0)->GetStreamFormat();
//
//    mLimiter = [[AELimiter alloc] initWithNumberOfChannels:GetNumberOfChannels() sampleRate:GetSampleRate()];
//
//    [mLimiter setLevel:1.0];
//    [mLimiter setAttack:(44100 * 10)];
//
//    mFloatConverter = [[AEFloatConverter alloc] initWithSourceFormat:clientFormat];
//    mScratchBufferChannelCount = GetNumberOfChannels();
//
//    mScratchBuffer = (float**)malloc(sizeof(float *) * mScratchBufferChannelCount);
//    
//    for (int i = 0; i < clientFormat.mChannelsPerFrame; i++) {
//        mScratchBuffer[i] = (float *)malloc(sizeof(float) * kScratchBufferLength);
//    }
    AudioStreamBasicDescription clientFormat = GetOutput(0)->GetStreamFormat();

    mBuffer.Allocate(GetNumberOfChannels(), clientFormat.mBytesPerFrame, GetSampleRate() * 2);
    
    mAttack = mSampleTime = 44100;
    
	return AUEffectBase::Initialize();
}


void EmergencyLimiter::Cleanup()
{
//    if (mScratchBuffer) {
//        for (int i = 0; i < mScratchBufferChannelCount; i++) {
//            free(mScratchBuffer[i]);
//        }
//
//        free(mScratchBuffer);
//        mScratchBuffer = NULL;
//    }
//
//    mLimiter = nil;
//    mFloatConverter = nil;

    mBuffer.Deallocate();

    
	AUEffectBase::Cleanup();
}


void EmergencyLimiter::_dequeue(float** buffers, UInt32 *ioLength, AudioTimeStamp *timestamp) {
    // Dequeue the audio
    int numberOfBuffers = _audioDescription.mChannelsPerFrame;
    char audioBufferListBytes[sizeof(AudioBufferList)+(numberOfBuffers-1)*sizeof(AudioBuffer)];
    AudioBufferList *bufferList = (AudioBufferList*)audioBufferListBytes;
    bufferList->mNumberBuffers = numberOfBuffers;
    for ( int i=0; i<numberOfBuffers; i++ ) {
        bufferList->mBuffers[i].mData = buffers[i];
        bufferList->mBuffers[i].mDataByteSize = sizeof(float) * *ioLength;
        bufferList->mBuffers[i].mNumberChannels = 1;
    }
    _audioDescription.mChannelsPerFrame = numberOfBuffers;
    TPCircularBufferDequeueBufferListFrames(&_buffer, ioLength, bufferList, timestamp, &_audioDescription);
    
    // Now apply limiting
    int frameNumber = 0;
    while ( frameNumber < *ioLength ) {
        
        // Examine buffer, update and act on state
        int stateDuration = *ioLength - frameNumber;
        switch ( _state ) {
            case kStateIdle: {
                if ( _framesToNextTrigger == kNoValue ) {
                    // See if there's a trigger up ahead
                    element_t trigger = findNextTriggerValueInRange(bufferList, frameNumber, NSMakeRange(0, (*ioLength-frameNumber)+_attack));
                    if ( trigger.value ) {
                        _framesToNextTrigger = trigger.index;
                        _triggerValue = trigger.value;
                    }
                }
                
                if ( _framesToNextTrigger <= _attack ) {
                    // We're within the attack duration - start attack now
                    _state = kStateAttacking;
                    continue;
                } else {
                    // Some time until attack, stay idle until then
                    stateDuration = min(stateDuration, _framesToNextTrigger - _attack);
                    
                    if ( stateDuration == _framesToNextTrigger - _attack ) {
                        _state = kStateAttacking;
                    }
                }
                break;
            }
            case kStateAttacking: {
                // See if there's a higher value in the next block
                element_t value = findMaxValueInRange(bufferList, frameNumber, NSMakeRange(_framesToNextTrigger, _framesToNextTrigger+_attack));
                if ( value.value > _triggerValue ) {
                    // Re-adjust target hold level to higher value
                    _triggerValue = value.value;
                }
                
                // Continue attack up to next trigger value
                stateDuration = min(_framesToNextTrigger, stateDuration);
#ifdef DEBUG
                assert(stateDuration >= 0);
#endif
                
                if ( stateDuration > 0 ) {
                    // Apply ramp
                    float step = ((_level/_triggerValue)-_gain) / _framesToNextTrigger;
                    if ( numberOfBuffers == 2 ) {
                        vDSP_vrampmul2(buffers[0]+frameNumber, buffers[1]+frameNumber, 1, &_gain, &step, buffers[0]+frameNumber, buffers[1]+frameNumber, 1, stateDuration);
                    } else {
                        float gain = _gain;
                        for ( int channel=0; channel<numberOfBuffers; channel++ ) {
                            gain = _gain;
                            vDSP_vrampmul(buffers[channel]+frameNumber, 1, &gain, &step, buffers[channel]+frameNumber, 1, stateDuration);
                        }
                        _gain = gain;
                    }
                } else {
                    _gain = _level / _triggerValue;
                }
                
                if ( stateDuration == _framesToNextTrigger ) {
                    _state = kStateHolding;
                }
                
                break;
            }
            case kStateHolding: {
                // See if there's a higher value within the remaining hold interval or following attack frames
                stateDuration = _framesToNextTrigger != kNoValue 
                                        ? _framesToNextTrigger + _hold 
                                        : MAX(0, (int)_hold - _framesSinceLastTrigger);

                element_t value = findMaxValueInRange(bufferList, frameNumber, NSMakeRange(0, stateDuration + _attack));
                if ( value.value > _triggerValue ) {
                    // Target attack to this new value
                    _framesToNextTrigger = value.index;
                    _triggerValue = value.value;
                    stateDuration = min(stateDuration, _framesToNextTrigger - _attack);
                    if ( stateDuration == _framesToNextTrigger - _attack ) {
                        _state = kStateAttacking;
                    }
                } else if ( value.value >= _level ) {
                    // Extend hold up to this value
                    _framesToNextTrigger = value.index;
                    stateDuration = min(stateDuration, MAX(_framesToNextTrigger, (int)_hold - _framesSinceLastTrigger));
                } else {
                    // Prepare to decay
                    if ( stateDuration == (int)_hold - _framesSinceLastTrigger ) {
                        _state = kStateDecaying;
                    }
                }
                
                stateDuration = min(*ioLength-frameNumber, stateDuration);
#ifdef DEBUG
                assert(stateDuration >= 0);
#endif
                
                // Apply gain
                for ( int i=0; i<numberOfBuffers; i++ ) {
                    vDSP_vsmul(buffers[i] + frameNumber, 1, &_gain, buffers[i] + frameNumber, 1, stateDuration);
                }
                
                break;
            }
            case kStateDecaying: {
                // See if there's a trigger up ahead
                stateDuration = min(stateDuration, _decay - (_framesSinceLastTrigger - _hold));
                element_t trigger = findNextTriggerValueInRange(bufferList, frameNumber, NSMakeRange(0, stateDuration+_attack));
                if ( trigger.value ) {
                    _framesToNextTrigger = trigger.index;
                    _triggerValue = trigger.value;
                    
                    stateDuration = min(stateDuration, trigger.index - _attack);
                    
                    if ( stateDuration == trigger.index - _attack ) {
                        _state = kStateAttacking;
                    }
                } else {
                    // Prepare to idle
                    if ( stateDuration == _decay - (_framesSinceLastTrigger - _hold) ) {
                        _state = kStateIdle;
                    }
                }
                
#ifdef DEBUG
                assert(stateDuration >= 0);
#endif
                
                if ( stateDuration > 0 ) {
                    // Apply ramp
                    float step = (1.0-_gain) / (_decay - (_framesSinceLastTrigger - _hold));
                    if ( numberOfBuffers == 2 ) {
                        vDSP_vrampmul2(buffers[0] + frameNumber, buffers[1] + frameNumber, 1, &_gain, &step, buffers[0] + frameNumber, buffers[1] + frameNumber, 1, stateDuration);
                    } else {
                        float gain = _gain;
                        for ( int channel=0; channel<numberOfBuffers; channel++ ) {
                            gain = _gain;
                            vDSP_vrampmul(buffers[channel] + frameNumber, 1, &_gain, &step, buffers[channel] + frameNumber, 1, stateDuration);
                        }
                        _gain = gain;
                    }
                } else {
                    _gain = 1;
                }

                break;
            }
        }
        
        frameNumber += stateDuration;
        advanceTime(stateDuration);
    }
}


inline void EmergencyLimiter::advanceTime(UInt32 frames)
{
    if ( _framesSinceLastTrigger != kNoValue ) {
        _framesSinceLastTrigger += frames;
        if ( _framesSinceLastTrigger > _hold+_decay ) {
            _framesSinceLastTrigger = kNoValue;
        }
    }
    if ( _framesToNextTrigger != kNoValue ) {
        _framesToNextTrigger -= frames;
        if ( _framesToNextTrigger <= 0 ) {
            _framesSinceLastTrigger = -_framesToNextTrigger;
            _framesToNextTrigger = kNoValue;
        }
    }
}


element_t EmergencyLimiter::findNextTriggerValueInRange(AudioBufferList *dequeuedBufferList, int dequeuedBufferListOffset, NSRange range)
{
    int framesSeen = 0;
    AudioBufferList *buffer = dequeuedBufferList;
    while ( framesSeen < range.location+range.length && buffer ) {
        int bufferOffset = buffer == dequeuedBufferList ? dequeuedBufferListOffset : 0;
        if ( framesSeen < range.location ) {
            int skip = min((buffer->mBuffers[0].mDataByteSize/sizeof(float))-bufferOffset, range.location-framesSeen);
            framesSeen += skip;
            bufferOffset += skip;
        }
        
        if ( framesSeen >= range.location && bufferOffset < (buffer->mBuffers[0].mDataByteSize/sizeof(float)) ) {
            // Find the first value greater than the limit
            for ( int i=0; i<buffer->mNumberBuffers; i++ ) {
                float *start = (float*)buffer->mBuffers[i].mData + bufferOffset;
                float *end = (float*)((char*)buffer->mBuffers[i].mData + buffer->mBuffers[i].mDataByteSize);
                end = MIN(end, start + ((range.location+range.length) - framesSeen));
                float *v=start;
                for ( ; v<end && fabsf(*v) < _level; v++ );
                if ( v != end ) {
                    return (element_t){ .value = fabsf(*v), .index = framesSeen + (v-start) };
                }
            }
            framesSeen += (buffer->mBuffers[0].mDataByteSize / sizeof(float)) - bufferOffset;
        }
        
        buffer = buffer == dequeuedBufferList 
            ? TPCircularBufferNextBufferList(&_buffer, NULL) :
              TPCircularBufferNextBufferListAfter(&_buffer, buffer, NULL);
    }
    
    return (element_t) {0, 0};
}


element_t EmergencyLimiter::findMaxValueInRange(AELimiter *THIS, AudioBufferList *dequeuedBufferList, int dequeuedBufferListOffset, NSRange range)
{
    vDSP_Length index = 0;
    float max = 0.0;
    int framesSeen = 0;
    AudioBufferList *buffer = dequeuedBufferList;
    while ( framesSeen < range.location+range.length && buffer ) {
        int bufferOffset = buffer == dequeuedBufferList ? dequeuedBufferListOffset : 0;
        if ( framesSeen < range.location ) {
            int skip = min((buffer->mBuffers[0].mDataByteSize/sizeof(float))-bufferOffset, range.location-framesSeen);
            framesSeen += skip;
            bufferOffset += skip;
        }
        
        if ( framesSeen >= range.location && bufferOffset < (buffer->mBuffers[0].mDataByteSize/sizeof(float)) ) {
            // Find max value
            for ( int i=0; i<buffer->mNumberBuffers; i++ ) {
                float *position = (float*)buffer->mBuffers[i].mData + bufferOffset;
                int length = (buffer->mBuffers[i].mDataByteSize / sizeof(float)) - bufferOffset;
                length = MIN(length, ((range.location+range.length) - framesSeen));
                
                vDSP_Length buffer_max_index;
                float buffer_max = max;
                for ( int i=0; i<buffer->mNumberBuffers; i++ ) {
                    vDSP_maxmgvi(position, 1, &buffer_max, &buffer_max_index, length);
                }
                
                if ( buffer_max > max ) {
                    max = buffer_max;
                    index = framesSeen + buffer_max_index;
                }
            }
            framesSeen += (buffer->mBuffers[0].mDataByteSize / sizeof(float)) - bufferOffset;
        }
        
        buffer = buffer == dequeuedBufferList 
            ? TPCircularBufferNextBufferList(&_buffer, NULL) :
              TPCircularBufferNextBufferListAfter(&_buffer, buffer, NULL);
    }
    
    return (element_t) { .value = max, .index = index};
}



OSStatus EmergencyLimiter::ChangeStreamFormat(
    AudioUnitScope inScope,
    AudioUnitElement inElement,
    const CAStreamBasicDescription &inPrevFormat,
    const CAStreamBasicDescription &inNewFormat
)
{
    inNewFormat.Print();
    
    return noErr;
}


OSStatus EmergencyLimiter::ProcessBufferLists(
    AudioUnitRenderActionFlags &	ioActionFlags,
    const AudioBufferList &			inBuffer,
    AudioBufferList &				outBuffer,
    UInt32							inFramesToProcess
)
{

    mBuffer.Store(&inBuffer, inFramesToProcess,  mSampleTime);
    mBuffer.Fetch(&outBuffer, inFramesToProcess, mSampleTime - mAttack);
    
    mSampleTime += inFramesToProcess;

    return noErr;
}



