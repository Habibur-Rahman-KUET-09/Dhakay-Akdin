#!/usr/bin/env python3
"""Makes the game's spoken lines with Azure's Bangla voices from
Bangladesh, into game/voices/<id>.mp3.

    AZURE_SPEECH_KEY=... AZURE_SPEECH_REGION=southeastasia python3 tool/make_voices.py

Lines come from game/content/voices.json (street talk: "<group>_<n>")
and game/content/story.json (the story, each line by its speaker:
"story_<first 10 of md5(speaker|text)>"). Only new or changed lines are
made (game/voices/manifest.json remembers what each file was made
from); files for lines that are gone are removed. Run by the voices
workflow, which has the key as a repository secret; without a key it
does nothing.
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
CONTENT = os.path.join(HERE, '..', 'game', 'content')
OUT = os.path.join(HERE, '..', 'game', 'voices')
FORMAT = 'audio-24khz-48kbitrate-mono-mp3'


def story_id(by, text):
    return 'story_' + hashlib.md5(f'{by}|{text}'.encode('utf-8')).hexdigest()[:10]


def wanted():
    """Every line to speak: {id: (speaker, text)}."""
    v = json.load(open(os.path.join(CONTENT, 'voices.json'), encoding='utf-8'))
    out = {}
    for group, lines in v['lines'].items():
        for i, line in enumerate(lines):
            out[f'{group}_{i}'] = (line['by'], line['bn'])
    story = json.load(open(os.path.join(CONTENT, 'story.json'), encoding='utf-8'))
    for c in story['chapters']:
        lines = [l for p in c['panels'] for l in p['lines']]
        for o in c.get('choice', {}).get('options', []):
            lines += o['lines']
        for l in lines:
            out[story_id(l['by'], l['bn'])] = (l['by'], l['bn'])
    return out, v['voices']


def ssml(voice, text):
    return (f"<speak version='1.0' xml:lang='bn-BD'><voice name='{voice['voice']}'>"
            f"<prosody pitch='{voice.get('pitch', '+0%')}' rate='{voice.get('rate', '+0%')}'>"
            f"{escape(text)}</prosody></voice></speak>")


def speak(key, region, body):
    url = f'https://{region}.tts.speech.microsoft.com/cognitiveservices/v1'
    req = urllib.request.Request(url, body.encode('utf-8'), {
        'Ocp-Apim-Subscription-Key': key,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': FORMAT,
        'User-Agent': 'praner-dhaka-voices',
    })
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            # The free tier allows only a few requests at a time.
            if e.code == 429 or e.code >= 500:
                time.sleep(5 * (attempt + 1))
                continue
            raise SystemExit(f'Azure said {e.code}: {e.read()[:300]!r}')
    raise SystemExit('Azure kept refusing (too many requests)')


def main():
    key = os.environ.get('AZURE_SPEECH_KEY', '')
    region = os.environ.get('AZURE_SPEECH_REGION', '')
    if not key or not region:
        print('::notice title=Voices::no AZURE_SPEECH_KEY / AZURE_SPEECH_REGION secret, nothing made')
        return
    lines, voices = wanted()
    os.makedirs(OUT, exist_ok=True)
    manifest_path = os.path.join(OUT, 'manifest.json')
    manifest = json.load(open(manifest_path, encoding='utf-8')) if os.path.exists(manifest_path) else {}
    made = 0
    for id_, (by, text) in sorted(lines.items()):
        if by not in voices:
            raise SystemExit(f'{id_}: no voice for speaker "{by}" in voices.json')
        body = ssml(voices[by], text)
        stamp = hashlib.md5(body.encode('utf-8')).hexdigest()
        path = os.path.join(OUT, f'{id_}.mp3')
        if manifest.get(id_) == stamp and os.path.exists(path):
            continue
        open(path, 'wb').write(speak(key, region, body))
        manifest[id_] = stamp
        made += 1
        time.sleep(0.4)
    gone = [i for i in manifest if i not in lines]
    for i in gone:
        manifest.pop(i)
        p = os.path.join(OUT, f'{i}.mp3')
        if os.path.exists(p):
            os.remove(p)
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
        f.write('\n')
    print(f'::notice title=Voices::{made} made, {len(gone)} removed, {len(lines)} in all')


if __name__ == '__main__':
    sys.exit(main())
