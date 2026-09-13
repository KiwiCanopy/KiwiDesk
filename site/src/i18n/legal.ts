// Legal pages (Impressum + Datenschutzerklärung) content, per locale.
//
// The GERMAN version is the legally authoritative one — German law (§ 5 DDG,
// § 18 MStV, DSGVO) governs the site's operation. `en` and `ja` are courtesy
// translations and carry a note pointing back to the binding German text.
//
// Scope is deliberately narrow: this is the *website* for KiwiDesk (a free
// macOS app) — a static marketing landing + Starlight documentation on
// Cloudflare Pages. It runs NO analytics, NO cookies, NO accounts, NO payment,
// NO fonts/embeds from third parties; docs diagrams (Mermaid) render fully
// client-side. The only client-side storage is three technically-necessary
// Local-Storage keys (theme + landing mode + language). The KiwiDesk app is
// distributed via GitHub and is out of scope here. Keep this file honest — a
// Datenschutzerklärung must describe the *actual* processing.

export type Lang = "en" | "de" | "ja";

export const OPERATOR = {
  name: "Maikel Hajiabadi",
  designation: "KiwiCanopy",
  address: ["Moselstraße 43", "60329 Frankfurt am Main"],
  email: "hello.kiwicanopy+kiwidesk@gmail.com",
} as const;

const MAILTO = `<a href="mailto:${OPERATOR.email}">${OPERATOR.email}</a>`;

export interface LegalSection {
  title: string;
  /** Trusted, hand-authored HTML (rendered via set:html). */
  body: string;
}
export interface LegalDoc {
  title: string;
  updated: string;
  sections: LegalSection[];
}
export interface LegalStrings {
  impressum: LegalDoc;
  datenschutz: LegalDoc;
  /** Terms of use for the site and the software — added 2026-09-13. */
  nutzungsbedingungen: LegalDoc;
  updatedLabel: string;
  backHome: string;
  /** Shown above non-German docs — German is binding. */
  translationNote?: string;
}

// ---------------------------------------------------------------- German (DE)
const de: LegalStrings = {
  updatedLabel: "Stand:",
  backHome: "Zurück zur Startseite",
  impressum: {
    title: "Impressum",
    updated: "28. Juli 2026",
    sections: [
      {
        title: "Angaben gemäß § 5 DDG",
        body: `<p><strong>${OPERATOR.name}</strong><br>${OPERATOR.designation}<br>${OPERATOR.address[0]}<br>${OPERATOR.address[1]}</p>`,
      },
      {
        title: "Kontakt",
        body: `<p>E-Mail: ${MAILTO}</p>`,
      },
      {
        title: "Verantwortlich für den Inhalt nach § 18 Abs. 2 MStV",
        body: `<p>${OPERATOR.name} (Anschrift wie oben).</p>`,
      },
      {
        title: "Haftung für Links",
        body:
          `<p>Diese Website enthält Links zu externen Websites Dritter (u. a. GitHub, Ko-fi und ` +
          `die Website des Anbieters kiwicanopy.com), auf deren Inhalte kein Einfluss besteht. ` +
          `Für diese fremden Inhalte wird keine Gewähr übernommen. Für die Inhalte der verlinkten ` +
          `Seiten ist stets der jeweilige Anbieter oder Betreiber verantwortlich. Bei ` +
          `Bekanntwerden von Rechtsverletzungen werden derartige Links umgehend entfernt.</p>`,
      },
      {
        title: "Verbraucherstreitbeilegung",
        body:
          `<p>Es besteht weder die Bereitschaft noch die Verpflichtung, an einem ` +
          `Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle teilzunehmen.</p>`,
      },
    ],
  },
  datenschutz: {
    title: "Datenschutzerklärung",
    updated: "28. Juli 2026",
    sections: [
      {
        title: "1. Datenschutz auf einen Blick",
        body:
          `<p>Die folgenden Hinweise geben einen einfachen Überblick darüber, was mit deinen ` +
          `personenbezogenen Daten passiert, wenn du diese Website besuchst. Personenbezogene ` +
          `Daten sind alle Daten, mit denen du persönlich identifiziert werden kannst.</p>` +
          `<p>KiwiDesk ist eine kostenlos nutzbare Anwendung (Tiling-Window-Manager für macOS). Diese ` +
          `Website ist die zugehörige Informations- und Dokumentationsseite (Marketing-Startseite ` +
          `sowie Dokumentation). Es gibt keine Benutzerkonten, keine Anmeldung, kein ` +
          `Kontaktformular, keine Zahlungsabwicklung und keine Analyse- oder Tracking-Dienste. Die ` +
          `KiwiDesk-App selbst wird über GitHub bereitgestellt; diese Datenschutzerklärung bezieht ` +
          `sich ausschließlich auf diese Website. Personenbezogene Daten fallen nur in dem ` +
          `technisch unvermeidbaren Umfang an, der zum Ausliefern der Website nötig ist ` +
          `(siehe „Hosting“).</p>`,
      },
      {
        title: "2. Verantwortliche Stelle",
        body:
          `<p>Verantwortlich für die Datenverarbeitung auf dieser Website ist:</p>` +
          `<p>${OPERATOR.name}<br>${OPERATOR.address[0]}<br>${OPERATOR.address[1]}<br>` +
          `E-Mail: ${MAILTO}</p>` +
          `<p>Verantwortliche Stelle ist die natürliche oder juristische Person, die allein oder ` +
          `gemeinsam mit anderen über die Zwecke und Mittel der Verarbeitung von ` +
          `personenbezogenen Daten entscheidet.</p>`,
      },
      {
        title: "3. Hosting (Cloudflare Pages)",
        body:
          `<p>Diese Website wird bei einem externen Dienstleister gehostet. Anbieter ist die ` +
          `<strong>Cloudflare, Inc., 101 Townsend St, San Francisco, CA 94107, USA</strong> ` +
          `(„Cloudflare Pages“). In der EU wird Cloudflare durch die Cloudflare Germany GmbH, ` +
          `Rosenheimer Straße 143 C, 81671 München, vertreten.</p>` +
          `<p>Beim Aufruf der Website erfasst Cloudflare als Hoster automatisch Zugriffsdaten in ` +
          `sogenannten Server-Log-Dateien. Dazu gehören insbesondere die IP-Adresse, ` +
          `Datum und Uhrzeit des Zugriffs, die aufgerufene Seite, der verwendete Browser und das ` +
          `Betriebssystem. Diese Daten sind technisch erforderlich, um die Website sicher und ` +
          `zuverlässig auszuliefern und Angriffe abzuwehren. Die Server-Log-Daten werden nur so ` +
          `lange gespeichert, wie es für die genannten Sicherheits- und Betriebszwecke ` +
          `erforderlich ist, und anschließend regelmäßig nach kurzer Zeit gelöscht oder ` +
          `anonymisiert, sofern kein sicherheitsrelevantes Ereignis eine längere Speicherung ` +
          `erfordert.</p>` +
          `<p>Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO (berechtigtes Interesse an einer ` +
          `sicheren und effizienten Bereitstellung der Website). Cloudflare betreibt ein ` +
          `weltweites Content-Delivery-Network (CDN); dabei kann eine Datenübermittlung in die ` +
          `USA erfolgen. Diese wird auf die Standardvertragsklauseln der EU-Kommission sowie auf ` +
          `das EU-US Data Privacy Framework (DPF) gestützt, unter dem Cloudflare zertifiziert ist. ` +
          `Es besteht ein Vertrag über Auftragsverarbeitung (AVV) mit Cloudflare.</p>`,
      },
      {
        title: "4. Lokaler Browser-Speicher (Local Storage)",
        body:
          `<p>Zur Speicherung deiner Anzeige-Einstellungen nutzt diese Website die ` +
          `Web-Storage-Technik (Local Storage) deines Browsers. Gespeichert werden ausschließlich ` +
          `drei Werte:</p>` +
          `<ul><li><code>starlight-theme</code> — deine Wahl zwischen hellem und dunklem Design ` +
          `(mit der Dokumentation geteilt)</li>` +
          `<li><code>kiwidesk-site-mode</code> — der Ansichtsmodus der Startseite ` +
          `(„einfach“ oder „erweitert“)</li>` +
          `<li><code>kiwidesk-site-lang</code> — deine bevorzugte Sprache (en, de oder ja)</li></ul>` +
          `<p>Diese Angaben verbleiben ausschließlich lokal auf deinem Endgerät und werden zu ` +
          `keinem Zeitpunkt an einen Server übertragen. Es findet kein Zugriff darauf statt. Es ` +
          `handelt sich nicht um Cookies. Die Speicherung dient allein der Nutzerfreundlichkeit ` +
          `und ist für die gewählte Funktion technisch erforderlich (§ 25 Abs. 2 Nr. 2 TDDDG; ` +
          `Art. 6 Abs. 1 lit. f DSGVO). Du kannst diese Werte jederzeit durch Leeren des ` +
          `Browser-Speichers löschen.</p>`,
      },
      {
        title: "5. Keine Cookies, kein Tracking",
        body:
          `<p>Diese Website setzt keine Cookies und verwendet keine Analyse-, Tracking- oder ` +
          `Werbedienste. Es werden keine Nutzungsprofile erstellt und keine Daten an Dritte zu ` +
          `Analysezwecken weitergegeben. Es werden keine externen Schriftarten (z. B. Google ` +
          `Fonts) geladen; die Seite verwendet die auf deinem Gerät vorhandenen ` +
          `System-Schriftarten. Alle weiteren Ressourcen werden lokal von dieser Website ` +
          `ausgeliefert; es werden keine externen Inhalte oder Einbettungen nachgeladen. Diagramme ` +
          `in der Dokumentation werden clientseitig in deinem Browser erzeugt; dabei werden keine ` +
          `externen Dienste kontaktiert.</p>`,
      },
      {
        title: "6. Kontaktaufnahme per E-Mail",
        body:
          `<p>Wenn du uns per E-Mail kontaktierst, werden deine Angaben inklusive der von dir ` +
          `mitgeteilten Kontaktdaten zum Zweck der Bearbeitung deiner Anfrage und für den Fall ` +
          `von Anschlussfragen gespeichert. Rechtsgrundlage ist unser berechtigtes Interesse an ` +
          `der Beantwortung deiner Anfrage (Art. 6 Abs. 1 lit. f DSGVO) bzw. Art. 6 Abs. 1 lit. b ` +
          `DSGVO, sofern die Anfrage auf einen Vertrag abzielt. Diese Daten werden gelöscht, ` +
          `sobald sie für die Erreichung des Zwecks nicht mehr erforderlich sind, sofern keine ` +
          `gesetzlichen Aufbewahrungspflichten entgegenstehen.</p>`,
      },
      {
        title: "7. Externe Links",
        body:
          `<p>Diese Website verlinkt auf externe Angebote (u. a. GitHub, Ko-fi sowie die Website ` +
          `des Anbieters kiwicanopy.com). Eine Datenübertragung an diese Anbieter findet erst ` +
          `statt, wenn du einen entsprechenden Link aktiv anklickst und die jeweilige Seite ` +
          `aufrufst. Ab diesem Zeitpunkt gelten die Datenschutzbestimmungen des jeweiligen ` +
          `Anbieters.</p>`,
      },
      {
        title: "8. SSL-/TLS-Verschlüsselung",
        body:
          `<p>Diese Seite nutzt aus Sicherheitsgründen eine SSL- bzw. TLS-Verschlüsselung. Eine ` +
          `verschlüsselte Verbindung erkennst du an „https://“ in der Adresszeile deines ` +
          `Browsers.</p>`,
      },
      {
        title: "9. Deine Rechte",
        body:
          `<p>Du hast im Rahmen der geltenden gesetzlichen Bestimmungen jederzeit das Recht auf ` +
          `unentgeltliche Auskunft über deine gespeicherten personenbezogenen Daten, deren ` +
          `Herkunft und Empfänger und den Zweck der Datenverarbeitung sowie ggf. ein Recht auf ` +
          `Berichtigung, Einschränkung, Löschung, Datenübertragbarkeit und Widerspruch. Hierzu ` +
          `sowie zu weiteren Fragen kannst du dich jederzeit an die oben genannte verantwortliche ` +
          `Stelle wenden.</p>` +
          `<p>Des Weiteren steht dir ein Beschwerderecht bei der zuständigen ` +
          `Datenschutz-Aufsichtsbehörde zu.</p>`,
      },
      {
        title: "10. Widerspruchsrecht (Art. 21 DSGVO)",
        body:
          `<p>Soweit die Verarbeitung deiner personenbezogenen Daten auf Grundlage berechtigter ` +
          `Interessen (Art. 6 Abs. 1 lit. f DSGVO) erfolgt, hast du das Recht, aus Gründen, die ` +
          `sich aus deiner besonderen Situation ergeben, jederzeit gegen diese Verarbeitung ` +
          `Widerspruch einzulegen. Wir verarbeiten die betroffenen Daten dann nicht mehr, es sei ` +
          `denn, wir können zwingende schutzwürdige Gründe nachweisen, die deine Interessen, ` +
          `Rechte und Freiheiten überwiegen, oder die Verarbeitung dient der Geltendmachung, ` +
          `Ausübung oder Verteidigung von Rechtsansprüchen.</p>` +
          `<p>Eine automatisierte Entscheidungsfindung einschließlich Profiling findet nicht ` +
          `statt.</p>`,
      },
    ],
  },
  nutzungsbedingungen: {
    title: "Nutzungsbedingungen",
    updated: "13. September 2026",
    sections: [
      {
        title: "1. Geltungsbereich",
        body:
          `<p>Diese Bedingungen gelten für die Nutzung der Website kiwidesk.kiwicanopy.com ` +
          `(einschließlich der Dokumentation) und der Software KiwiDesk. Betreiber und Anbieter ` +
          `ist ${OPERATOR.name}, ${OPERATOR.designation} (Anschrift und Kontakt im Impressum).</p>`,
      },
      {
        title: "2. Software und Lizenz",
        body:
          `<p>KiwiDesk wird ab Version 1.3.0 unter der <strong>Business Source License 1.1</strong> ` +
          `bereitgestellt. Der vollständige Lizenztext liegt dem Quellcode bei und ist in der App ` +
          `unter „Über“ abrufbar. Die Lizenz erlaubt die <strong>kostenlose Nutzung der ` +
          `Software</strong>, auch in oder für ein Unternehmen. Das Anbieten, Verkaufen, ` +
          `Bündeln oder Hosten der Software oder eines abgeleiteten Werks als Produkt oder ` +
          `Dienst setzt eine kommerzielle Lizenz des Betreibers voraus; Anfragen per E-Mail ` +
          `an ${MAILTO}.</p>` +
          `<p>Jede Version von KiwiDesk wird vier Jahre nach ihrer Erstveröffentlichung unter die ` +
          `MIT-Lizenz gestellt. Versionen vor 1.3.0 wurden unter der MIT-Lizenz veröffentlicht ` +
          `und bleiben es. Bei Widersprüchen zwischen diesen Bedingungen und dem Lizenztext gilt ` +
          `der Lizenztext.</p>`,
      },
      {
        title: "3. Bereitstellung, Updates und Support",
        body:
          `<p>Die Software wird in der jeweils veröffentlichten Fassung bereitgestellt. Es besteht ` +
          `kein Anspruch auf Verfügbarkeit, bestimmte Funktionen, Updates oder Support. Die App ` +
          `prüft auf Updates; Einzelheiten dazu stehen in der Datenschutzerklärung. Die ` +
          `Installation erfolgt über die auf der Website angebotenen Wege.</p>`,
      },
      {
        title: "4. Gewährleistung und Haftung",
        body:
          `<p>Für die unentgeltlich überlassene Software gilt der Gewährleistungs- und ` +
          `Haftungsausschluss des Lizenztextes. Unberührt bleibt die Haftung für Vorsatz und grobe ` +
          `Fahrlässigkeit, für Schäden aus der Verletzung des Lebens, des Körpers oder der ` +
          `Gesundheit sowie nach dem Produkthaftungsgesetz.</p>`,
      },
      {
        title: "5. Kennzeichen",
        body:
          `<p>„KiwiDesk“, „KiwiCanopy“ und die zugehörigen Logos sind Kennzeichen des Betreibers. ` +
          `Die Softwarelizenz räumt keine Rechte an diesen Kennzeichen ein.</p>`,
      },
      {
        title: "6. Nutzung der Website",
        body:
          `<p>Die Website erfordert kein Konto und bietet keine Bestellung oder Zahlung an. ` +
          `Die Inhalte der Website sind urheberrechtlich geschützt; die Dokumentation steht unter ` +
          `der Lizenz des Quellcode-Repositorys. Für externe Links gilt das Impressum.</p>`,
      },
      {
        title: "7. Änderungen",
        body:
          `<p>Der Betreiber kann diese Bedingungen mit Wirkung für die Zukunft ändern. Es gilt die ` +
          `auf dieser Seite veröffentlichte Fassung mit dem oben angegebenen Stand.</p>`,
      },
      {
        title: "8. Anwendbares Recht",
        body:
          `<p>Es gilt das Recht der Bundesrepublik Deutschland. Zwingende ` +
          `Verbraucherschutzvorschriften des Staates, in dem Verbraucher ihren gewöhnlichen ` +
          `Aufenthalt haben, bleiben unberührt.</p>`,
      },
    ],
  },
};

// -------------------------------------------------------------- English (EN)
const en: LegalStrings = {
  updatedLabel: "Last updated:",
  backHome: "Back to home",
  translationNote:
    "This is a courtesy translation. The legally binding version of these notices is the German original (Impressum / Datenschutzerklärung).",
  impressum: {
    title: "Legal Notice (Impressum)",
    updated: "28 July 2026",
    sections: [
      {
        title: "Information pursuant to § 5 DDG",
        body: `<p><strong>${OPERATOR.name}</strong><br>${OPERATOR.designation}<br>${OPERATOR.address[0]}<br>${OPERATOR.address[1]}</p>`,
      },
      {
        title: "Contact",
        body: `<p>Email: ${MAILTO}</p>`,
      },
      {
        title: "Responsible for content pursuant to § 18 (2) MStV",
        body: `<p>${OPERATOR.name} (address as above).</p>`,
      },
      {
        title: "Liability for links",
        body:
          `<p>This website contains links to external third-party websites (including GitHub, ` +
          `Ko-fi, and the provider's website kiwicanopy.com) over whose content we have no ` +
          `control. No liability is accepted for such external content. The respective provider ` +
          `or operator is always responsible for the content of linked pages. Such links will be ` +
          `removed immediately if any legal infringements become known.</p>`,
      },
      {
        title: "Consumer dispute resolution",
        body:
          `<p>We are neither willing nor obliged to participate in dispute resolution proceedings ` +
          `before a consumer arbitration board.</p>`,
      },
    ],
  },
  datenschutz: {
    title: "Privacy Policy",
    updated: "28 July 2026",
    sections: [
      {
        title: "1. Privacy at a glance",
        body:
          `<p>The following notes provide a simple overview of what happens to your personal data ` +
          `when you visit this website. Personal data is any data that can be used to identify ` +
          `you personally.</p>` +
          `<p>KiwiDesk is a free-to-use application (a tiling window manager for macOS). This website is ` +
          `its informational and documentation site (a marketing landing page plus ` +
          `documentation). There are no user accounts, no sign-in, no contact form, no payment ` +
          `processing, and no analytics or tracking services. The KiwiDesk app itself is ` +
          `distributed via GitHub; this privacy policy relates solely to this website. Personal ` +
          `data is only processed to the technically unavoidable extent required to deliver the ` +
          `website (see “Hosting”).</p>`,
      },
      {
        title: "2. Responsible party",
        body:
          `<p>The party responsible for data processing on this website is:</p>` +
          `<p>${OPERATOR.name}<br>${OPERATOR.address[0]}<br>${OPERATOR.address[1]}<br>` +
          `Email: ${MAILTO}</p>` +
          `<p>The responsible party is the natural or legal person who alone or jointly with ` +
          `others determines the purposes and means of processing personal data.</p>`,
      },
      {
        title: "3. Hosting (Cloudflare Pages)",
        body:
          `<p>This website is hosted by an external service provider. The provider is ` +
          `<strong>Cloudflare, Inc., 101 Townsend St, San Francisco, CA 94107, USA</strong> ` +
          `(“Cloudflare Pages”). In the EU, Cloudflare is represented by Cloudflare Germany GmbH, ` +
          `Rosenheimer Straße 143 C, 81671 Munich, Germany.</p>` +
          `<p>When the website is accessed, Cloudflare as the host automatically collects access ` +
          `data in so-called server log files. This includes in particular the IP address, the ` +
          `date and time of access, the page requested, the browser used, and the operating ` +
          `system. This data is technically necessary to deliver the website securely and ` +
          `reliably and to defend against attacks. The server log data is stored only for as ` +
          `long as necessary for the stated security and operational purposes and is then ` +
          `routinely deleted or anonymized after a short period, unless a security-relevant ` +
          `incident requires longer storage.</p>` +
          `<p>The legal basis is Art. 6 (1) (f) GDPR (legitimate interest in the secure and ` +
          `efficient provision of the website). Cloudflare operates a global content delivery ` +
          `network (CDN); this may involve a transfer of data to the USA. Such transfers are ` +
          `based on the EU Commission's Standard Contractual Clauses and the EU-US Data Privacy ` +
          `Framework (DPF), under which Cloudflare is certified. A data processing agreement ` +
          `(DPA) is in place with Cloudflare.</p>`,
      },
      {
        title: "4. Local browser storage (Local Storage)",
        body:
          `<p>To store your display preferences, this website uses your browser's web storage ` +
          `(Local Storage). Only three values are stored:</p>` +
          `<ul><li><code>starlight-theme</code> — your choice between light and dark design ` +
          `(shared with the documentation)</li>` +
          `<li><code>kiwidesk-site-mode</code> — the landing-page view mode ` +
          `(“simple” or “advanced”)</li>` +
          `<li><code>kiwidesk-site-lang</code> — your preferred language (en, de or ja)</li></ul>` +
          `<p>These values remain solely on your device and are never transmitted to a server. ` +
          `They are not accessed by us. They are not cookies. This storage serves only usability ` +
          `and is technically necessary for the selected function (§ 25 (2) no. 2 TDDDG; ` +
          `Art. 6 (1) (f) GDPR). You can delete these values at any time by clearing your ` +
          `browser storage.</p>`,
      },
      {
        title: "5. No cookies, no tracking",
        body:
          `<p>This website does not set cookies and does not use any analytics, tracking, or ` +
          `advertising services. No usage profiles are created and no data is passed to third ` +
          `parties for analysis purposes. No external fonts (such as Google Fonts) are loaded; ` +
          `the site uses the system fonts present on your device. All other resources are served ` +
          `locally by this website; no external content or embeds are loaded. Diagrams in the ` +
          `documentation are rendered client-side in your browser; no external services are ` +
          `contacted in the process.</p>`,
      },
      {
        title: "6. Contact by email",
        body:
          `<p>If you contact us by email, your details, including the contact data you provide, ` +
          `will be stored for the purpose of processing your request and in case of follow-up ` +
          `questions. The legal basis is our legitimate interest in answering your request ` +
          `(Art. 6 (1) (f) GDPR), or Art. 6 (1) (b) GDPR where the request relates to a ` +
          `contract. This data is deleted once it is no longer required to achieve the purpose, ` +
          `provided no statutory retention obligations apply.</p>`,
      },
      {
        title: "7. External links",
        body:
          `<p>This website links to external services (including GitHub, Ko-fi, and the ` +
          `provider's website kiwicanopy.com). Data is only transmitted to these providers once ` +
          `you actively click a corresponding link and visit the respective page. From that ` +
          `point on, the privacy policies of the respective provider apply.</p>`,
      },
      {
        title: "8. SSL/TLS encryption",
        body:
          `<p>For security reasons, this site uses SSL/TLS encryption. You can recognize an ` +
          `encrypted connection by the “https://” in your browser's address bar.</p>`,
      },
      {
        title: "9. Your rights",
        body:
          `<p>Within the framework of the applicable statutory provisions, you have the right at ` +
          `any time to free information about your stored personal data, its origin and ` +
          `recipients, and the purpose of the data processing, as well as, where applicable, a ` +
          `right to rectification, restriction, erasure, data portability, and objection. You ` +
          `can contact the responsible party named above at any time regarding this and other ` +
          `questions.</p>` +
          `<p>You also have the right to lodge a complaint with the competent data protection ` +
          `supervisory authority.</p>`,
      },
      {
        title: "10. Right to object (Art. 21 GDPR)",
        body:
          `<p>Where the processing of your personal data is based on legitimate interests ` +
          `(Art. 6 (1) (f) GDPR), you have the right to object at any time, on grounds relating ` +
          `to your particular situation, to such processing. We will then no longer process the ` +
          `data concerned unless we can demonstrate compelling legitimate grounds for the ` +
          `processing that override your interests, rights, and freedoms, or the processing ` +
          `serves to assert, exercise, or defend legal claims.</p>` +
          `<p>No automated decision-making, including profiling, takes place.</p>`,
      },
    ],
  },
  nutzungsbedingungen: {
    title: "Terms of Service",
    updated: "13 September 2026",
    sections: [
      {
        title: "1. Scope",
        body:
          `<p>These terms govern the use of the website kiwidesk.kiwicanopy.com (including the ` +
          `documentation) and of the KiwiDesk software. The operator and provider is ` +
          `${OPERATOR.name}, ${OPERATOR.designation} (address and contact in the Legal Notice).</p>`,
      },
      {
        title: "2. Software and license",
        body:
          `<p>From version 1.3.0, KiwiDesk is provided under the <strong>Business Source License ` +
          `1.1</strong>. The full license text ships with the source code and can be opened in the ` +
          `app under “About”. The license permits <strong>use of the software free of ` +
          `charge</strong>, including within or on behalf of a business. Offering, selling, ` +
          `bundling or hosting the software or a derivative of it as a product or service ` +
          `requires a commercial license from the operator; enquiries by email to ${MAILTO}.</p>` +
          `<p>Each version of KiwiDesk converts to the MIT License four years after it is first ` +
          `published. Versions published before 1.3.0 were released under the MIT License and ` +
          `remain so. Where these terms and the license text differ, the license text prevails.</p>`,
      },
      {
        title: "3. Provision, updates and support",
        body:
          `<p>The software is provided in the version published at the time. There is no ` +
          `entitlement to availability, particular features, updates or support. The app checks ` +
          `for updates; details are in the privacy policy. Installation is through the channels ` +
          `offered on the website.</p>`,
      },
      {
        title: "4. Warranty and liability",
        body:
          `<p>For the software, which is provided free of charge, the warranty and liability ` +
          `disclaimer of the license text applies. Liability for intent and gross negligence, for ` +
          `injury to life, body or health, and under the German Product Liability Act remains ` +
          `unaffected.</p>`,
      },
      {
        title: "5. Trademarks",
        body:
          `<p>“KiwiDesk”, “KiwiCanopy” and the associated logos are marks of the operator. The ` +
          `software license grants no rights to them.</p>`,
      },
      {
        title: "6. Use of the website",
        body:
          `<p>The website requires no account and offers no ordering or payment. Its content is ` +
          `protected by copyright; the documentation is covered by the license of the source ` +
          `repository. External links are subject to the Legal Notice.</p>`,
      },
      {
        title: "7. Changes",
        body:
          `<p>The operator may change these terms with effect for the future. The version ` +
          `published on this page, with the date stated above, applies.</p>`,
      },
      {
        title: "8. Governing law",
        body:
          `<p>The law of the Federal Republic of Germany applies. Mandatory consumer-protection ` +
          `provisions of the state in which a consumer habitually resides remain unaffected.</p>`,
      },
    ],
  },
};

// -------------------------------------------------------------- Japanese (JA)
const ja: LegalStrings = {
  updatedLabel: "最終更新:",
  backHome: "ホームに戻る",
  translationNote:
    "本文は参考のための翻訳です。法的に有効なのはドイツ語の原文（Impressum / Datenschutzerklärung）です。",
  impressum: {
    title: "運営者情報（Impressum）",
    updated: "2026年7月28日",
    sections: [
      {
        title: "DDG 第5条に基づく情報",
        body: `<p><strong>${OPERATOR.name}</strong><br>${OPERATOR.designation}<br>${OPERATOR.address[0]}<br>${OPERATOR.address[1]}</p>`,
      },
      {
        title: "連絡先",
        body: `<p>メール: ${MAILTO}</p>`,
      },
      {
        title: "MStV 第18条第2項に基づくコンテンツ責任者",
        body: `<p>${OPERATOR.name}（住所は上記のとおり）。</p>`,
      },
      {
        title: "リンクに関する責任",
        body:
          `<p>本ウェブサイトには第三者の外部サイト（GitHub、Ko-fi、および提供者のウェブサイト ` +
          `kiwicanopy.com など）へのリンクが含まれます。これらの内容に当方は影響を及ぼすことが ` +
          `できず、その内容について保証しません。リンク先の内容については、それぞれの提供者または ` +
          `運営者が常に責任を負います。法令違反が判明した場合、当該リンクは速やかに削除します。</p>`,
      },
      {
        title: "消費者紛争解決",
        body:
          `<p>当方は、消費者仲裁機関における紛争解決手続に参加する意思も義務もありません。</p>`,
      },
    ],
  },
  datenschutz: {
    title: "プライバシーポリシー",
    updated: "2026年7月28日",
    sections: [
      {
        title: "1. 概要",
        body:
          `<p>以下は、本ウェブサイトを訪問された際にあなたの個人データがどのように扱われるかについての ` +
          `簡単な概要です。個人データとは、あなたを個人として特定できるすべてのデータを指します。</p>` +
          `<p>KiwiDesk は利用が無料のアプリケーション（macOS 向けタイル型ウィンドウマネージャー）です。 ` +
          `本ウェブサイトはその情報・ドキュメントサイト（マーケティング用トップページおよび ` +
          `ドキュメント）です。ユーザーアカウント、ログイン、問い合わせフォーム、決済処理、解析・ ` +
          `トラッキングサービスはいずれもありません。KiwiDesk アプリ本体は GitHub で配布されており、 ` +
          `本プライバシーポリシーは本ウェブサイトのみを対象とします。個人データは、ウェブサイトを ` +
          `配信するために技術的に避けられない範囲でのみ処理されます（「ホスティング」参照）。</p>`,
      },
      {
        title: "2. 責任者",
        body:
          `<p>本ウェブサイトにおけるデータ処理の責任者は以下のとおりです:</p>` +
          `<p>${OPERATOR.name}<br>${OPERATOR.address[0]}<br>${OPERATOR.address[1]}<br>` +
          `メール: ${MAILTO}</p>` +
          `<p>責任者とは、単独または他者と共同で個人データ処理の目的および手段を決定する自然人 ` +
          `または法人を指します。</p>`,
      },
      {
        title: "3. ホスティング（Cloudflare Pages）",
        body:
          `<p>本ウェブサイトは外部のサービス提供者によってホスティングされています。提供者は ` +
          `<strong>Cloudflare, Inc., 101 Townsend St, San Francisco, CA 94107, USA</strong> ` +
          `（「Cloudflare Pages」）です。EU においては、Cloudflare Germany GmbH ` +
          `（Rosenheimer Straße 143 C, 81671 München）が Cloudflare を代表します。</p>` +
          `<p>ウェブサイトへのアクセス時、ホストである Cloudflare はいわゆるサーバーログファイルに ` +
          `アクセスデータを自動的に記録します。これには特に IP アドレス、アクセス日時、要求された ` +
          `ページ、使用ブラウザ、OS が含まれます。これらのデータは、ウェブサイトを安全かつ確実に ` +
          `配信し、攻撃を防御するために技術的に必要です。サーバーログデータは、上記のセキュリティ ` +
          `および運用の目的に必要な期間のみ保存され、その後は短期間で定期的に削除または匿名化 ` +
          `されます。ただし、セキュリティ上重要な事象がある場合はより長く保存されることがあります。</p>` +
          `<p>法的根拠は GDPR 第6条第1項(f)（安全かつ効率的なウェブサイト提供に対する正当な利益）です。 ` +
          `Cloudflare は世界規模のコンテンツ配信ネットワーク（CDN）を運用しており、米国へのデータ ` +
          `移転が生じる場合があります。これは EU 委員会の標準契約条項および Cloudflare が認証を受けて ` +
          `いる EU-US Data Privacy Framework（DPF）に基づいて行われます。Cloudflare とは委託処理 ` +
          `契約（AVV/DPA）を締結しています。</p>`,
      },
      {
        title: "4. ブラウザのローカルストレージ（Local Storage）",
        body:
          `<p>表示設定を保存するため、本ウェブサイトはブラウザの Web ストレージ（Local Storage）を ` +
          `使用します。保存される値は次の3つのみです:</p>` +
          `<ul><li><code>starlight-theme</code> — ライト／ダークデザインの選択（ドキュメントと共有）</li>` +
          `<li><code>kiwidesk-site-mode</code> — トップページの表示モード（「シンプル」または「詳細」）</li>` +
          `<li><code>kiwidesk-site-lang</code> — 優先言語（en、de、ja）</li></ul>` +
          `<p>これらの値はあなたの端末上にのみ保持され、サーバーへ送信されることは一切ありません。 ` +
          `当方がこれらにアクセスすることもありません。これらは Cookie ではありません。この保存は ` +
          `利便性のみを目的とし、選択された機能に技術的に必要です（TDDDG 第25条第2項第2号、 ` +
          `GDPR 第6条第1項(f)）。ブラウザのストレージを消去することで、これらの値はいつでも削除できます。</p>`,
      },
      {
        title: "5. Cookie・トラッキングなし",
        body:
          `<p>本ウェブサイトは Cookie を設定せず、解析・トラッキング・広告サービスを一切使用しません。 ` +
          `利用プロファイルの作成や、解析目的での第三者へのデータ提供は行いません。外部フォント ` +
          `（Google Fonts など）は読み込まれず、本サイトはお使いの端末にあるシステムフォントを ` +
          `使用します。その他すべてのリソースは本ウェブサイトからローカルに配信され、外部コンテンツ ` +
          `や埋め込みは読み込まれません。ドキュメント内の図表はお使いのブラウザ上でクライアントサイド ` +
          `で描画され、その際に外部サービスへ接続することはありません。</p>`,
      },
      {
        title: "6. メールによるお問い合わせ",
        body:
          `<p>メールでご連絡いただいた場合、お問い合わせの処理および追加のご質問に備えるため、 ` +
          `ご提供いただいた連絡先を含む情報を保存します。法的根拠は、お問い合わせに回答することへの ` +
          `正当な利益（GDPR 第6条第1項(f)）、または契約に関わる場合は GDPR 第6条第1項(b)です。 ` +
          `これらのデータは、目的の達成に不要となり次第、法定の保存義務がない限り削除されます。</p>`,
      },
      {
        title: "7. 外部リンク",
        body:
          `<p>本ウェブサイトは外部サービス（GitHub、Ko-fi、および提供者のウェブサイト kiwicanopy.com ` +
          `など）へのリンクを含みます。これらの提供者へのデータ送信は、対応するリンクをあなたが実際に ` +
          `クリックし、当該ページを訪問した時点で初めて発生します。それ以降は、各提供者の ` +
          `プライバシーポリシーが適用されます。</p>`,
      },
      {
        title: "8. SSL／TLS 暗号化",
        body:
          `<p>本サイトはセキュリティ上の理由から SSL／TLS 暗号化を使用しています。暗号化された接続は、 ` +
          `ブラウザのアドレスバーの「https://」で確認できます。</p>`,
      },
      {
        title: "9. あなたの権利",
        body:
          `<p>適用される法令の枠内で、あなたはいつでも、保存されている個人データ、その出所と受領者、 ` +
          `およびデータ処理の目的について無償で情報提供を受ける権利を有し、必要に応じて訂正、制限、 ` +
          `削除、データポータビリティ、異議申立ての権利を有します。これらおよびその他のご質問に ` +
          `ついては、上記の責任者にいつでもご連絡いただけます。</p>` +
          `<p>また、管轄のデータ保護監督機関に苦情を申し立てる権利も有します。</p>`,
      },
      {
        title: "10. 異議申立ての権利（GDPR 第21条）",
        body:
          `<p>あなたの個人データの処理が正当な利益（GDPR 第6条第1項(f)）に基づいて行われる場合、` +
          `あなたは自身の特別な状況から生じる理由により、いつでも当該処理に異議を申し立てる権利を ` +
          `有します。その場合、当方は、あなたの利益・権利・自由に優先するやむを得ない保護に値する ` +
          `理由を証明できる場合、または当該処理が法的請求の主張・行使・防御に資する場合を除き、 ` +
          `当該データを処理しません。</p>` +
          `<p>プロファイリングを含む自動化された意思決定は行われません。</p>`,
      },
    ],
  },
  nutzungsbedingungen: {
    title: "利用規約",
    updated: "2026年9月13日",
    sections: [
      {
        title: "1. 適用範囲",
        body:
          `<p>本規約は、ウェブサイト kiwidesk.kiwicanopy.com（ドキュメントを含む）およびソフトウェア ` +
          `KiwiDesk の利用に適用されます。運営者・提供者は ${OPERATOR.name}（${OPERATOR.designation}、` +
          `住所と連絡先は運営者情報のとおり）です。</p>`,
      },
      {
        title: "2. ソフトウェアとライセンス",
        body:
          `<p>KiwiDesk はバージョン 1.3.0 以降、<strong>Business Source License 1.1</strong> のもとで` +
          `提供されます。ライセンス全文はソースコードに同梱され、アプリの「About」から開けます。` +
          `ライセンスは<strong>本ソフトウェアの利用を無償で</strong>認めます。企業内または企業のための` +
          `利用も含みます。本ソフトウェアやその派生物を製品またはサービスとして` +
          `提供・販売・同梱・ホスティングすることには、運営者の商用ライセンスが必要です。` +
          `お問い合わせは ${MAILTO} まで。</p>` +
          `<p>KiwiDesk の各バージョンは、初回公開から 4 年後に MIT ライセンスへ移行します。1.3.0 より前の` +
          `バージョンは MIT ライセンスで公開されており、今後もそのままです。本規約とライセンス本文が` +
          `異なる場合は、ライセンス本文が優先します。</p>`,
      },
      {
        title: "3. 提供、アップデート、サポート",
        body:
          `<p>ソフトウェアはその時点で公開されているバージョンのまま提供されます。可用性、特定の機能、` +
          `アップデート、サポートを受ける権利はありません。アプリはアップデートを確認します。詳細は` +
          `プライバシーポリシーをご覧ください。インストールはウェブサイトで案内する方法によります。</p>`,
      },
      {
        title: "4. 保証と責任",
        body:
          `<p>無償で提供されるソフトウェアには、ライセンス本文の保証および責任の免責が適用されます。` +
          `故意または重過失による責任、生命・身体・健康の侵害による損害の責任、およびドイツ製造物責任法` +
          `に基づく責任は影響を受けません。</p>`,
      },
      {
        title: "5. 商標",
        body:
          `<p>「KiwiDesk」「KiwiCanopy」および関連するロゴは運営者の標章です。ソフトウェアライセンスは` +
          `これらに対するいかなる権利も付与しません。</p>`,
      },
      {
        title: "6. ウェブサイトの利用",
        body:
          `<p>ウェブサイトにはアカウントは不要で、注文や支払いの機能もありません。コンテンツは著作権で` +
          `保護されています。ドキュメントはソースリポジトリのライセンスに従います。外部リンクについては` +
          `運営者情報をご覧ください。</p>`,
      },
      {
        title: "7. 変更",
        body:
          `<p>運営者は本規約を将来に向けて変更することがあります。本ページに掲載された、上記の日付の` +
          `版が適用されます。</p>`,
      },
      {
        title: "8. 準拠法",
        body:
          `<p>ドイツ連邦共和国の法律が適用されます。消費者が常居所を有する国の強行的な消費者保護規定は` +
          `影響を受けません。</p>`,
      },
    ],
  },
};

export const legal: Record<Lang, LegalStrings> = { en, de, ja };
