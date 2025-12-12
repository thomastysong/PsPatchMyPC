import { motion } from 'framer-motion'
import Scene from '../components/Scene'
import DrawnPath, { DrawnText, DrawnCircle, DrawnLine, DrawnRect } from '../components/DrawnPath'

/**
 * SolutionScene - Presents PsPatchMyPC as the solution
 * Logo reveal followed by key feature diagram
 */
function SolutionScene() {
  return (
    <Scene viewBox="0 0 900 500">
      {/* Logo/Title reveal with flourish */}
      <motion.g
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ duration: 0.8, ease: 'backOut' }}
      >
        {/* PowerShell-style prompt bracket */}
        <DrawnPath
          d="M 280 35 L 265 50 L 280 65"
          delay={0.3}
          duration={0.5}
          stroke="#00d9ff"
          strokeWidth={4}
        />
        
        {/* Main title */}
        <DrawnText
          x={450}
          y={60}
          fontSize={44}
          fontWeight={700}
          delay={0.4}
          duration={1}
          fill="#00d9ff"
        >
          PsPatchMyPC
        </DrawnText>

        {/* Closing bracket */}
        <DrawnPath
          d="M 620 35 L 635 50 L 620 65"
          delay={0.6}
          duration={0.5}
          stroke="#00d9ff"
          strokeWidth={4}
        />
      </motion.g>

      {/* Tagline */}
      <DrawnText x={450} y={95} fontSize={20} delay={1.0} fill="#88d8b0">
        Enterprise Patching, Reimagined
      </DrawnText>

      {/* Central hub circle */}
      <DrawnCircle cx={450} cy={260} r={45} delay={1.3} stroke="#00d9ff" strokeWidth={3} />
      <DrawnText x={450} y={255} fontSize={14} delay={1.6} fill="#00d9ff">winget</DrawnText>
      <DrawnText x={450} y={275} fontSize={14} delay={1.7} fill="#00d9ff">powered</DrawnText>

      {/* --- Feature 1: Automation (Top Left) --- */}
      <g>
        {/* Connecting line from center */}
        <DrawnPath
          d="M 410 230 Q 340 180 280 160"
          delay={2.0}
          duration={0.6}
          stroke="#00d9ff"
          strokeWidth={2}
          opacity={0.6}
        />
        
        {/* Feature circle */}
        <DrawnCircle cx={230} cy={140} r={35} delay={2.2} stroke="#feca57" strokeWidth={2} />
        
        {/* Gear icon inside */}
        <DrawnPath
          d="M 230 125 L 230 120 M 245 140 L 250 140 M 230 155 L 230 160 M 215 140 L 210 140"
          delay={2.4}
          stroke="#feca57"
          strokeWidth={2}
        />
        <DrawnCircle cx={230} cy={140} r={12} delay={2.5} stroke="#feca57" strokeWidth={2} />
        
        {/* Label */}
        <DrawnText x={230} y={195} fontSize={18} delay={2.6} fill="#feca57">
          Automatic Updates
        </DrawnText>
        <DrawnText x={230} y={215} fontSize={14} delay={2.8} fill="#888">
          Set it and forget it
        </DrawnText>
      </g>

      {/* --- Feature 2: Progressive Deferrals (Top Right) --- */}
      <g>
        {/* Connecting line from center */}
        <DrawnPath
          d="M 490 230 Q 560 180 620 160"
          delay={3.0}
          duration={0.6}
          stroke="#00d9ff"
          strokeWidth={2}
          opacity={0.6}
        />
        
        {/* Feature circle */}
        <DrawnCircle cx={670} cy={140} r={35} delay={3.2} stroke="#88d8b0" strokeWidth={2} />
        
        {/* Clock icon inside */}
        <DrawnCircle cx={670} cy={140} r={15} delay={3.4} stroke="#88d8b0" strokeWidth={2} />
        <DrawnLine x1={670} y1={140} x2={670} y2={130} delay={3.5} stroke="#88d8b0" strokeWidth={2} />
        <DrawnLine x1={670} y1={140} x2={678} y2={145} delay={3.6} stroke="#88d8b0" strokeWidth={2} />
        
        {/* Snooze indicators */}
        <DrawnText x={695} y={125} fontSize={12} delay={3.7} fill="#88d8b0">z</DrawnText>
        <DrawnText x={703} y={118} fontSize={10} delay={3.8} fill="#88d8b0">z</DrawnText>
        
        {/* Label */}
        <DrawnText x={670} y={195} fontSize={18} delay={3.9} fill="#88d8b0">
          Smart Deferrals
        </DrawnText>
        <DrawnText x={670} y={215} fontSize={14} delay={4.1} fill="#888">
          Users stay in control
        </DrawnText>
      </g>

      {/* --- Feature 3: Orchestrator Integration (Bottom Left) --- */}
      <g>
        {/* Connecting line from center */}
        <DrawnPath
          d="M 410 290 Q 340 340 280 360"
          delay={4.3}
          duration={0.6}
          stroke="#00d9ff"
          strokeWidth={2}
          opacity={0.6}
        />
        
        {/* Feature circle */}
        <DrawnCircle cx={230} cy={380} r={35} delay={4.5} stroke="#a29bfe" strokeWidth={2} />
        
        {/* Network/integration icon */}
        <DrawnCircle cx={220} cy={370} r={6} delay={4.7} stroke="#a29bfe" strokeWidth={1.5} />
        <DrawnCircle cx={240} cy={370} r={6} delay={4.8} stroke="#a29bfe" strokeWidth={1.5} />
        <DrawnCircle cx={230} cy={390} r={6} delay={4.9} stroke="#a29bfe" strokeWidth={1.5} />
        <DrawnLine x1={223} y1={373} x2={237} y2={373} delay={5.0} stroke="#a29bfe" strokeWidth={1.5} />
        <DrawnLine x1={222} y1={376} x2={228} y2={384} delay={5.1} stroke="#a29bfe" strokeWidth={1.5} />
        <DrawnLine x1={238} y1={376} x2={232} y2={384} delay={5.2} stroke="#a29bfe" strokeWidth={1.5} />
        
        {/* Label */}
        <DrawnText x={230} y={435} fontSize={18} delay={5.3} fill="#a29bfe">
          Intune • FleetDM • SCCM
        </DrawnText>
        <DrawnText x={230} y={455} fontSize={14} delay={5.5} fill="#888">
          Works with your tools
        </DrawnText>
      </g>

      {/* --- Feature 4: Logging & Compliance (Bottom Right) --- */}
      <g>
        {/* Connecting line from center */}
        <DrawnPath
          d="M 490 290 Q 560 340 620 360"
          delay={5.7}
          duration={0.6}
          stroke="#00d9ff"
          strokeWidth={2}
          opacity={0.6}
        />
        
        {/* Feature circle */}
        <DrawnCircle cx={670} cy={380} r={35} delay={5.9} stroke="#fd79a8" strokeWidth={2} />
        
        {/* Document/log icon */}
        <DrawnRect x={655} y={365} width={20} height={28} rx={2} delay={6.1} stroke="#fd79a8" strokeWidth={1.5} />
        <DrawnLine x1={660} y1={373} x2={670} y2={373} delay={6.2} stroke="#fd79a8" strokeWidth={1.5} />
        <DrawnLine x1={660} y1={379} x2={670} y2={379} delay={6.3} stroke="#fd79a8" strokeWidth={1.5} />
        <DrawnLine x1={660} y1={385} x2={668} y2={385} delay={6.4} stroke="#fd79a8" strokeWidth={1.5} />
        
        {/* Checkmark */}
        <DrawnPath d="M 680 380 L 685 387 L 695 372" delay={6.5} stroke="#88d8b0" strokeWidth={2} />
        
        {/* Label */}
        <DrawnText x={670} y={435} fontSize={18} delay={6.6} fill="#fd79a8">
          CMTrace + Event Logs
        </DrawnText>
        <DrawnText x={670} y={455} fontSize={14} delay={6.8} fill="#888">
          Audit-ready always
        </DrawnText>
      </g>

      {/* Subtle animation ring around center */}
      <motion.circle
        cx={450}
        cy={260}
        r={60}
        fill="none"
        stroke="#00d9ff"
        strokeWidth={1}
        strokeDasharray="4 8"
        initial={{ opacity: 0, rotate: 0 }}
        animate={{ opacity: 0.4, rotate: 360 }}
        transition={{
          opacity: { delay: 2, duration: 0.5 },
          rotate: { delay: 2, duration: 20, repeat: Infinity, ease: 'linear' }
        }}
        style={{ transformOrigin: '450px 260px' }}
      />

      {/* Bottom flourish */}
      <DrawnPath
        d="M 300 480 Q 450 490 600 480"
        delay={7.2}
        duration={0.8}
        stroke="#00d9ff"
        strokeWidth={2}
        opacity={0.5}
      />
    </Scene>
  )
}

export default SolutionScene

