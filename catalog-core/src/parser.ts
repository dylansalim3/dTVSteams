import { JSDOM } from "jsdom";

export type Episode = { id: string; title: string; date: string; url: string };
export type Part = { label: string; url: string };

export function parseList(html: string): Episode[] {
  const dom = new JSDOM(html);
  const anchors = dom.window.document.querySelectorAll("ul.lcp_catlist a");
  const out: Episode[] = [];
  anchors.forEach((a: Element) => {
    const title = (a.textContent ?? "").trim();
    const url = (a as HTMLAnchorElement).href ?? "";
    if (!title || !url) return;
    const m = title.match(/\d{4}-\d{2}-\d{2}/);
    out.push({ id: url, title, date: m ? m[0] : "", url });
  });
  return out;
}

export function parseParts(html: string, baseUrl: string): Part[] {
  const dom = new JSDOM(html);
  const items = dom.window.document.querySelectorAll("ul.contentlist li");
  const out: Part[] = [];
  items.forEach((li: Element) => {
    const a = li.querySelector("a");
    if (a) {
      const label = (a.textContent ?? "").trim();
      const url = (a as HTMLAnchorElement).href || baseUrl;
      out.push({ label, url });
    } else {
      const label = (li.textContent ?? "").trim();
      if (label) out.push({ label, url: baseUrl });
    }
  });
  return out;
}
