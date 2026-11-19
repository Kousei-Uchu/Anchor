import { useState } from 'react';
import { Segmented } from '../AnchorUI';
import { groundingToolDetail } from '../../../content/seed';

/**
 * The editor sheet that opens when you tap a grounding tool: its name, whether it is a physical action or a link, its steps (one per line),
 * and the times of day it is relevant. It looks like an iOS Form. Changes are not saved on the website.
 */
const TIMES: [string, string][] = [['morning', 'Morning'], ['afternoon', 'Afternoon'], ['evening', 'Evening'], ['lateNight', 'Late night']];

export default function GroundingToolSheet({ scheme, onClose, arg }: { scheme: 'light' | 'dark'; onClose: () => void; arg?: string }) {
  const tool = groundingToolDetail(arg ?? '');
  const [name, setName] = useState(tool?.title ?? '');
  const [kind, setKind] = useState(tool?.deepLink ? 'Deep link' : 'Physical action');
  const [steps, setSteps] = useState(tool?.steps ?? '');
  const [times, setTimes] = useState<string[]>(tool?.windows ?? []);
  return (
    <div className="au-sheet-wrap" data-anchor-scheme={scheme}>
      <div className="au-sheet-dim" onClick={onClose} />
      <div className="au-sheet au-sheet-form" data-anchor-scheme={scheme} role="dialog" aria-label="Edit grounding tool">
        <div className="au-formbar"><span>{name || 'Grounding tool'}</span><button type="button" onClick={onClose}>Done</button></div>
        <div className="au-form">
          <div className="au-formcard">
            <input className="au-formfield" value={name} onChange={(e) => setName(e.target.value)} aria-label="Name" />
            <div className="au-formrule" />
            <Segmented options={['Physical action', 'Deep link']} value={kind} onChange={setKind} />
          </div>
          <div className="au-formhead">Steps</div>
          <div className="au-formcard"><textarea className="au-formtext" value={steps} onChange={(e) => setSteps(e.target.value)} rows={6} aria-label="Steps" /></div>
          <div className="au-formnote">One step per line. Each line becomes its own screen you can step through one at a time. For example: "Feel your feet on the floor" on one line, "Take 3 slow breaths" on the next.</div>
          <div className="au-formhead">When it's relevant</div>
          <div className="au-formcard au-formrows">
            {TIMES.map(([key, label]) => (
              <div key={key} className="au-formrow">
                <span>{label}</span>
                <button type="button" role="switch" aria-checked={times.includes(key)} aria-label={label} className={`au-switch${times.includes(key) ? ' on' : ''}`} onClick={() => setTimes((t) => (t.includes(key) ? t.filter((x) => x !== key) : [...t, key]))}><i /></button>
              </div>
            ))}
          </div>
          <div className="au-formnote">Leave all off to show this tool at any time of day.</div>
        </div>
        <div className="au-formdelete"><button type="button" onClick={onClose}>Delete</button></div>
      </div>
    </div>
  );
}
