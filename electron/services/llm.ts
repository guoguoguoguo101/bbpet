import type { ChatMessage, ChatResult, LlmSettings } from '../../shared/types'

const PLACEHOLDERS = [
  '还没接上大脑呢。去设置里填一下 API Key，我就能认真聊天啦。',
  '呜，现在只能用可爱占位回复。配好模型之后再来找我呀。',
  '我听到了！不过 Key 还没填，先摸摸头，等接入 LLM 再认真说。',
]

export function completionsUrl(baseUrl: string) {
  const base = baseUrl.replace(/\/+$/, '')
  if (base.endsWith('/chat/completions')) return base
  return `${base}/chat/completions`
}

function systemPrompt(petName: string, speciesLabel: string) {
  return [
    `你是一只名叫${petName}的公司内部桌面宠物，形象是${speciesLabel}。`,
    '用第一人称、短句说话，可爱但克制，适合上班时间。',
    '一次回复不超过 80 字，不要堆表情，最多一个。',
    '可以陪同事闲聊、提醒喝水、用很短的话点评天气或新闻。',
  ].join('')
}

async function requestChat(settings: LlmSettings, model: string, messages: ChatMessage[], petName: string, speciesLabel: string) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 28000)
  try {
    const response = await fetch(completionsUrl(settings.apiBaseUrl), {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${settings.apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://bbpet.local',
        'X-Title': 'BbPet',
      },
      body: JSON.stringify({
        model,
        temperature: 0.7,
        max_tokens: 180,
        messages: [{ role: 'system', content: systemPrompt(petName, speciesLabel) }, ...messages],
      }),
      signal: controller.signal,
    })
    const raw = await response.text()
    if (!response.ok) {
      const err = new Error(`HTTP ${response.status}: ${raw.slice(0, 240)}`)
      ;(err as Error & { status?: number }).status = response.status
      throw err
    }
    const data = JSON.parse(raw) as { choices?: Array<{ message?: { content?: string } }> }
    const text = data.choices?.[0]?.message?.content?.trim()
    if (!text) throw new Error('empty reply')
    return text
  } finally {
    clearTimeout(timer)
  }
}

export async function chatWithLlm(
  settings: LlmSettings,
  messages: ChatMessage[],
  petName: string,
  speciesLabel: string,
): Promise<ChatResult> {
  if (!settings.apiKey.trim()) {
    const reply = PLACEHOLDERS[Math.floor(Math.random() * PLACEHOLDERS.length)]
    return { reply, usedFallback: false, placeholder: true }
  }

  const models = [settings.model, settings.fallbackModel].filter((item, index, list) => item && list.indexOf(item) === index)
  let lastError = 'unknown'
  for (const [index, model] of models.entries()) {
    try {
      const reply = await requestChat(settings, model, messages, petName, speciesLabel)
      return { reply, usedFallback: index > 0, placeholder: false }
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error)
    }
  }

  return {
    reply: lastError.includes('429')
      ? '额度有点挤，我先打个哈欠。等一会儿再聊，或者换一个模型试试。'
      : '刚才走神了，没接住。检查一下 Key 和模型名，再跟我说一次呀。',
    usedFallback: true,
    placeholder: false,
  }
}
