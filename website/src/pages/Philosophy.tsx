import { Link } from 'react-router-dom';
import { Page } from '../components/Page';
import { ABOUT_PRINCIPLES } from '../content/about';

export default function Philosophy() {
  return (
    <Page route="/philosophy" title="Philosophy" meta="What Anchor is trying to be, and what it is not">
      <p>
        Anchor is a private place for your safety plan, your people and your journal. You set it up while you are calm, so it is there when you are not. It is made by one person, and these are the rules I hold it to.
      </p>

      <h2>The three principles</h2>
      <ul>
        {ABOUT_PRINCIPLES.map((p) => (
          <li key={p}>{p}</li>
        ))}
      </ul>

      <h2>No scores, no verdicts</h2>
      <p>
        A check-in shows the five sliders where you left them, and nothing is added up. There is no mood score, no sleep score, no target hours and no streak of days you showed up. A Recovery counter shows time, and the longest run stays hidden until you ask to see it. A bad night or a long gap is never marked in red, because a record of your own life should not grade you.
      </p>

      <h2>Optional, and off until you say</h2>
      <p>
        Reminders, extra tools and anything that shows on a lock screen are off until you switch them on, each with its own switch. When a reminder does arrive, the lock screen says something plain that names no one and no feeling, so a glance at your phone tells nobody anything. You can use Anchor without changing a single setting.
      </p>

      <h2>Your words stay yours</h2>
      <p>
        Anchor keeps what you write as you wrote it. It does not guess how you feel, suggest what a pattern means, or fill in a section for you. Where an optional tool offers a suggestion, nothing happens until you accept it, and your own words are kept either way.
      </p>

      <h2>Nothing is sent for you</h2>
      <p>
        Anchor never messages anyone by itself. A reminder to reach out opens a message for you to read, change and send, and a missed check-in leads to a reminder to you, never to another person. Exports are files you make and choose to share, and you decide what goes into them.
      </p>

      <h2>Local first</h2>
      <p>
        There is no account, no server that receives your data, no advertising and no tracking. What you put in stays on your phone. The <Link to="/privacy">privacy policy</Link> lists every permission Anchor can ask for and what each one is used for.
      </p>

      <h2>Who it is for</h2>
      <p>
        Anchor is for someone who wants one calm place for a safety plan, the people they would reach for, a journal, and the things they want to bring to an appointment. It suits people who find apps that rate them, nag them or compare them to a goal more tiring than helpful.
      </p>

      <h2>Who it is not for</h2>
      <p>
        Anchor is not a medical device and not an emergency service. It does not diagnose anything, give advice about your health, or replace the people who look after you. It does not watch over you or tell anyone how you are doing. If you are in danger right now, call your local emergency number or a crisis line.
      </p>
      <p>
        To see how each part works, read the <Link to="/features">features</Link>.
      </p>
    </Page>
  );
}
