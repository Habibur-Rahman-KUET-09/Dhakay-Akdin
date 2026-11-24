#!/usr/bin/env python3
"""Tries the lines in tool/voice_trials.json a few ways each (another
voice, slower, the line in standard spelling, a mood from voices.json),
into <out dir>/<id>__<way>.mp3 with an index.json, so the player can hear
them side by side and pick.

A variant gives the voice for male and female speakers; "own": true starts
from the speaker's own pitch and rate; "only_with_say" speaks the line's
"say" spelling (skipped when it has none); "mood": true says it in the
line's "mood".

    AZURE_SPEECH_KEY=... AZURE_SPEECH_REGION=... python3 tool/make_voice_trials.py trials
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_voices as mv  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    out = sys.argv[1]
    key = os.environ.get('AZURE_SPEECH_KEY', '')
    region = os.environ.get('AZURE_SPEECH_REGION', '')
    if not key or not region:
        raise SystemExit('no AZURE_SPEECH_KEY / AZURE_SPEECH_REGION')
    trials = json.load(open(os.path.join(HERE, 'voice_trials.json'), encoding='utf-8'))
    lines, voices = mv.wanted()
    named = mv.moods()
    os.makedirs(out, exist_ok=True)
    index = []
    for id_, extra in trials['lines'].items():
        if id_ not in lines:
            print(f'::warning title=Voice trials::{id_} is not a line any more')
            continue
        by, text = lines[id_]
        sex = 'female' if 'Nabanita' in voices[by]['voice'] else 'male'
        ways = []
        for way, spec in trials['variants'].items():
            say = extra.get('say')
            if spec.get('only_with_say') and not say:
                continue
            voice = {**voices[by], **spec[sex]} if spec.get('own') else spec[sex]
            spoken = say if spec.get('only_with_say') else text
            mood = extra.get('mood') if spec.get('mood') else None
            if mood and mood not in named:
                raise SystemExit(f'{id_}: no mood "{mood}" in voices.json')
            name = f'{id_}__{way}.mp3'
            body = mv.ssml(voice, spoken, named.get(mood))
            open(os.path.join(out, name), 'wb').write(mv.speak(key, region, body))
            ways.append({'way': way, 'label': spec['label'], 'file': name, 'voice': voice,
                         'say': spoken if spoken != text else None, 'mood': mood})
            time.sleep(0.4)
        index.append({'id': id_, 'by': by, 'text': text, 'ways': ways})
    json.dump(index, open(os.path.join(out, 'index.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'::notice title=Voice trials::{sum(len(i["ways"]) for i in index)} tries of {len(index)} lines')


if __name__ == '__main__':
    main()
