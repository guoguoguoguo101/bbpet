import { useEffect, useRef, useState } from 'react'
import type { PushBubble } from '../../shared/types'
import { SpeechBubble } from './SpeechBubble'

export function BubbleApp() {
  const [payload, setPayload] = useState<PushBubble | null>(null)
  const boxRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    document.body.classList.add('bubble-host')
    return () => document.body.classList.remove('bubble-host')
  }, [])

  useEffect(() => {
    return window.bbpet.onShowBubble(setPayload)
  }, [])

  useEffect(() => {
    const node = boxRef.current
    if (!payload || !node) return
    const report = () => {
      const bubble = node.querySelector('.bubble')
      if (!(bubble instanceof HTMLElement)) return
      const width = Math.ceil(bubble.scrollWidth)
      const height = Math.ceil(bubble.scrollHeight)
      if (width > 0 && height > 0) window.bbpet.reportBubbleSize(width, height)
    }
    report()
    const observer = new ResizeObserver(report)
    observer.observe(node)
    return () => observer.disconnect()
  }, [payload])

  if (!payload) return null

  return (
    <div className="stage stage-bubble" ref={boxRef}>
      <SpeechBubble text={payload.text} kind={payload.kind} url={payload.url} />
    </div>
  )
}
