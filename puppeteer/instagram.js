const dotenv = require('dotenv');
dotenv.config({ path: `${__dirname}/../tokens.env` });

const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
      args: ['--remote-debugging-port=9222', '--no-sandbox'],
      userDataDir: `${__dirname}/user_data`,
      dumpio: true
  });
  const page = await browser.newPage();
  await page.setDefaultNavigationTimeout(0);

  console.log('Wait until page has loaded')

  await page.goto('https://www.instagram.com/accounts/login/', {
    waitUntil: 'domcontentloaded',
  });

  console.log('Wait for log in form')

  await Promise.all([
    page.waitForSelector('[name="username"]'),
    page.waitForSelector('[name="password"]'),
    page.waitForSelector('[type="submit"]'),
  ]);

  console.log('Enter username and password')

  await page.type('[name="username"]', process.env.BILU_INSTAGRAM_USERNAME);
  await page.type('[name="password"]', process.env.BILU_INSTAGRAM_PASSWORD);

  console.log('Submit log in credentials and wait for navigation')

  await Promise.all([
    page.click('[type="submit"]'),
    page.waitForNavigation({
      waitUntil: 'load',
    }),
  ]);

  console.log('Taking screenshot')
  await page.screenshot({ path: `${__dirname}/instagram.jpeg`, type: 'jpeg' });

  await browser.close();
})();

