interface SpeechBubbleProps {
  text: string
  kind?: string
  url?: string
}

export function SpeechBubble({ text, kind = 'chat', url }: SpeechBubbleProps) {
  const clickable = Boolean(url)
  return (
    <div
      className={`bubble bubble-${kind} ${clickable ? 'bubble-link' : ''}`}
      role={clickable ? 'link' : 'note'}
      onClick={() => {
        if (url) window.bbpet.openUrl(url)
      }}
    >
      <p>{text}</p>
      {clickable && <span className="bubble-hint">点击看原文</span>}
    </div>
  )
}
