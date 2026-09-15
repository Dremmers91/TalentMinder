import { chromium } from "playwright";

const url = process.argv[2];
if (!url) throw new Error("Usage: node tools/data-pipeline/scripts/inspect-source.mjs <url>");

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  const responses = [];
  page.on("response", (response) => {
    const type = response.request().resourceType();
    if (["fetch", "xhr", "document"].includes(type)) responses.push({ type, status: response.status(), url: response.url() });
  });
  await page.goto(url, { waitUntil: "networkidle", timeout: 60_000 });
  const details = await page.evaluate(() => ({
    title: document.title,
    text: document.body.innerText,
    html: document.documentElement.outerHTML,
    buttons: [...document.querySelectorAll("button")].map((button) => ({ text: button.innerText.trim(), aria: button.getAttribute("aria-label") })),
    inputs: [...document.querySelectorAll("input, textarea")].map((input) => ({ type: input.type, value: input.value, aria: input.getAttribute("aria-label") })),
  }));
  const exportPattern = /(?<![A-Za-z0-9+/=])[A-Za-z0-9+/=]{30,}(?![A-Za-z0-9+/=])/g;
  const candidates = [...new Set([...(details.text.match(exportPattern) || []), ...(details.html.match(exportPattern) || [])])];
  console.log(JSON.stringify({ title: details.title, candidates, buttons: details.buttons, inputs: details.inputs, responses, text: details.text.slice(0, 12_000) }, null, 2));
} finally {
  await browser.close();
}
