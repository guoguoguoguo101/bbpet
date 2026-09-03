import type { NewsItem } from '../../shared/types'

const FEEDS: Array<{ source: string; url: string }> = [
  { source: '少数派', url: 'https://sspai.com/feed' },
  { source: 'Solidot', url: 'https://www.solidot.org/index.rss' },
  { source: '人民网', url: 'http://www.people.com.cn/rss/politics.xml' },
]

function decodeXml(text: string) {
  return text
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/<[^>]+>/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}

function absUrl(raw: string) {
  const url = decodeXml(raw)
  return /^https?:\/\//i.test(url) ? url : ''
}

function linkFromBlock(block: string) {
  const href = block.match(/<link[^>]*href=["']([^"']+)["'][^>]*\/?>/i)?.[1]
  if (href && absUrl(href)) return absUrl(href)
  const link = block.match(/<link(?:\s[^>]*)?>([\s\S]*?)<\/link>/i)?.[1]
  if (link && absUrl(link)) return absUrl(link)
  const guid = block.match(/<guid(?:\s[^>]*)?>([\s\S]*?)<\/guid>/i)?.[1]
  if (guid && absUrl(guid)) return absUrl(guid)
  return ''
}

function itemsFromFeed(xml: string, source: string): NewsItem[] {
  const blocks = [...xml.matchAll(/<(?:item|entry)[\s\S]*?<\/(?:item|entry)>/gi)].map((match) => match[0])
  return blocks
    .map((block) => {
      const title = decodeXml(block.match(/<title(?:\s[^>]*)?>([\s\S]*?)<\/title>/i)?.[1] ?? '')
      const url = linkFromBlock(block)
      return { title, source, url }
    })
    .filter((item) => item.title.length > 4 && item.title.length < 80)
}

async function fetchText(url: string) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 12000)
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: { 'User-Agent': 'BbPet/1.0 (internal desktop pet)' },
    })
    if (!response.ok) throw new Error(`news ${response.status}`)
    return response.text()
  } finally {
    clearTimeout(timer)
  }
}

async function fetchZhihuFallback(): Promise<NewsItem[]> {
  const text = await fetchText('https://news-at.zhihu.com/api/4/news/latest')
  const data = JSON.parse(text) as { stories?: Array<{ title?: string; url?: string; id?: number }> }
  return (data.stories ?? [])
    .map((story) => {
      const title = story.title?.trim() ?? ''
      const url = story.url || (story.id ? `https://daily.zhihu.com/story/${story.id}` : '')
      return { title, source: '知乎日报', url }
    })
    .filter((item) => item.title)
}

export async function fetchNews(): Promise<NewsItem> {
  const errors: string[] = []
  for (const feed of FEEDS) {
    try {
      const xml = await fetchText(feed.url)
      const items = itemsFromFeed(xml, feed.source)
      const linked = items.filter((item) => item.url)
      const pool = linked.length > 0 ? linked : items
      if (pool.length > 0) return pool[Math.floor(Math.random() * Math.min(pool.length, 8))]
    } catch (error) {
      errors.push(`${feed.source}: ${error instanceof Error ? error.message : error}`)
    }
  }
  try {
    const items = await fetchZhihuFallback()
    if (items.length > 0) return items[Math.floor(Math.random() * Math.min(items.length, 6))]
  } catch (error) {
    errors.push(`zhihu: ${error instanceof Error ? error.message : error}`)
  }
  throw new Error(errors.join('; ') || 'news unavailable')
}
