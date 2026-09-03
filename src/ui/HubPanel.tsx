import { PixelPet } from '../pet/PixelPet'
import type { AppState } from '../../shared/types'

interface HubPanelProps {
  state: AppState
  inSchool: boolean
  inHome: boolean
  incoming: number
  onChat: () => void
  onSchool: () => void
  onHome: () => void
  onFriends: () => void
  onSettings: () => void
  onClose: () => void
}

export function HubPanel({
  state,
  inSchool,
  inHome,
  incoming,
  onChat,
  onSchool,
  onHome,
  onFriends,
  onSettings,
  onClose,
}: HubPanelProps) {
  const room = state.settings.roomUrl?.trim() || '未填写'

  return (
    <section className="panel hub-panel">
      <header className="panel-head">
        <strong>今天去哪</strong>
        <button type="button" className="ghost" onClick={onClose}>
          收起
        </button>
      </header>
      <div className="hub-hero">
        <PixelPet species={state.pet.species} colors={state.pet.colors} pose="idle" pixelSize={4} />
        <div>
          <p className="hub-name">{state.pet.name}</p>
          <p className="hint">点一下选地方。学校要连内网房主。</p>
        </div>
      </div>
      <div className="hub-actions">
        <button type="button" className="hub-btn" onClick={onChat}>
          <span>和宠物聊</span>
          <small>还是原来的悄悄话</small>
        </button>
        <button type="button" className="hub-btn hub-btn-main" onClick={onSchool}>
          <span>{inSchool ? '回到学校' : '去上学'}</span>
          <small>{inSchool ? '你还在学校里，黑板消息还在' : 'WASD 走动，教室黑板聊天'}</small>
        </button>
        <button type="button" className="hub-btn" onClick={onHome}>
          <span>回家</span>
          <small>{inHome ? '已经在房间里，桌面上能看见来串门的人' : '回自己房间，好友点进来就能看见你'}</small>
        </button>
        <button type="button" className="hub-btn" onClick={onFriends}>
          <span>好友{incoming > 0 ? `（${incoming}）` : ''}</span>
          <small>申请、列表，点名字进他家</small>
        </button>
      </div>
      <footer className="hub-foot">
        <span>学校地址 {room}</span>
        <button type="button" className="ghost" onClick={onSettings}>
          设置
        </button>
      </footer>
    </section>
  )
}
