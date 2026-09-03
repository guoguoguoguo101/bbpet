import { useEffect, useRef, useState } from 'react'
import type { ChatMessage } from '../../shared/types'

interface ChatPanelProps {
  name: string
  history: ChatMessage[]
  busy: boolean
  onSend: (text: string) => void
  onClose: () => void
}

export function ChatPanel({ name, history, busy, onSend, onClose }: ChatPanelProps) {
  const [draft, setDraft] = useState('')
  const endRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [history, busy])

  const submit = () => {
    const text = draft.trim()
    if (!text || busy) return
    setDraft('')
    onSend(text)
  }

  return (
    <section className="panel chat-panel">
      <header className="panel-head">
        <strong>和 {name} 聊天</strong>
        <button type="button" className="ghost" onClick={onClose}>
          收起
        </button>
      </header>
      <div className="chat-log">
        {history.length === 0 && <p className="hint">点一下就能聊。可以说天气、新闻，或随便问问今天开不开心。</p>}
        {history.map((item, index) => (
          <div key={`${item.role}-${index}`} className={`chat-row ${item.role}`}>
            <span>{item.content}</span>
          </div>
        ))}
        {busy && <div className="chat-row assistant pending">{name} 正在想...</div>}
        <div ref={endRef} />
      </div>
      <form
        className="chat-form"
        onSubmit={(event) => {
          event.preventDefault()
          submit()
        }}
      >
        <input
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder="跟桌宠说点什么"
          maxLength={200}
        />
        <button type="submit" disabled={busy || !draft.trim()}>
          发送
        </button>
      </form>
    </section>
  )
}
