import { motion } from 'framer-motion'
import Scene from '../components/Scene'
import DrawnPath, { DrawnText, DrawnRect, DrawnLine } from '../components/DrawnPath'

/**
 * CTAScene - Call to action with install command and links
 */
function CTAScene() {
  return (
    <Scene viewBox="0 0 900 500">
      {/* Main tagline with dramatic entrance */}
      <motion.g
        initial={{ scale: 0.5, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ duration: 0.8, ease: 'backOut' }}
      >
        <DrawnText
          x={450}
          y={80}
          fontSize={48}
          fontWeight={700}
          delay={0.2}
          duration={1.2}
          fill="#00d9ff"
        >
          Patch Smarter.
        </DrawnText>
        <DrawnText
          x={450}
          y={130}
          fontSize={48}
          fontWeight={700}
          delay={0.6}
          duration={1}
          fill="#88d8b0"
        >
          Not Harder.
        </DrawnText>
      </motion.g>

      {/* Decorative underline */}
      <DrawnPath
        d="M 250 150 C 350 165 550 165 650 150"
        delay={1.4}
        duration={0.8}
        stroke="#00d9ff"
        strokeWidth={2}
        opacity={0.6}
      />

      {/* PowerShell terminal box */}
      <g>
        {/* Terminal window frame */}
        <DrawnRect
          x={170}
          y={190}
          width={560}
          height={120}
          rx={8}
          delay={1.8}
          duration={1}
          stroke="#444"
          strokeWidth={2}
          fill="none"
        />
        
        {/* Terminal title bar */}
        <DrawnLine x1={170} y1={220} x2={730} y2={220} delay={2.0} stroke="#444" strokeWidth={1} />
        
        {/* Window controls (dots) */}
        <motion.circle
          cx={190}
          cy={205}
          r={5}
          fill="#ff5f57"
          initial={{ opacity: 0, scale: 0 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 2.2, duration: 0.3 }}
        />
        <motion.circle
          cx={210}
          cy={205}
          r={5}
          fill="#febc2e"
          initial={{ opacity: 0, scale: 0 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 2.3, duration: 0.3 }}
        />
        <motion.circle
          cx={230}
          cy={205}
          r={5}
          fill="#28c840"
          initial={{ opacity: 0, scale: 0 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 2.4, duration: 0.3 }}
        />

        {/* PowerShell prompt */}
        <DrawnText
          x={195}
          y={265}
          fontSize={18}
          fontFamily="'Consolas', 'Courier New', monospace"
          textAnchor="start"
          delay={2.6}
          fill="#00d9ff"
        >
          PS C:\&gt;
        </DrawnText>

        {/* Command - typed effect */}
        <motion.text
          x={280}
          y={265}
          fontSize={18}
          fontFamily="'Consolas', 'Courier New', monospace"
          fill="#f5f5f5"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 2.8, duration: 0.1 }}
        >
          <TypewriterText 
            text="Install-Module -Name PsPatchMyPC" 
            delay={2.8}
          />
        </motion.text>

        {/* Blinking cursor */}
        <motion.rect
          x={568}
          y={250}
          width={10}
          height={20}
          fill="#00d9ff"
          initial={{ opacity: 0 }}
          animate={{ opacity: [0, 1, 0] }}
          transition={{ 
            delay: 4.2,
            duration: 1,
            repeat: Infinity,
            repeatType: 'loop'
          }}
        />
      </g>

      {/* Links section */}
      <g>
        {/* PowerShell Gallery */}
        <motion.g
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 4.5, duration: 0.5 }}
        >
          <DrawnRect x={220} y={340} width={200} height={50} rx={6} delay={4.6} stroke="#a29bfe" strokeWidth={2} />
          <DrawnText x={320} y={372} fontSize={16} delay={4.8} fill="#a29bfe">
            PowerShell Gallery
          </DrawnText>
        </motion.g>

        {/* GitHub */}
        <motion.g
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 4.7, duration: 0.5 }}
        >
          <DrawnRect x={480} y={340} width={200} height={50} rx={6} delay={4.8} stroke="#feca57" strokeWidth={2} />
          <DrawnText x={580} y={372} fontSize={16} delay={5.0} fill="#feca57">
            GitHub
          </DrawnText>
        </motion.g>
      </g>

      {/* MIT License badge */}
      <motion.g
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.7 }}
        transition={{ delay: 5.2, duration: 0.5 }}
      >
        <DrawnText x={450} y={430} fontSize={14} delay={5.3} fill="#888">
          MIT License • Open Source • Free Forever
        </DrawnText>
      </motion.g>

      {/* Sparkle accents */}
      <motion.g
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 5, duration: 0.5 }}
      >
        <Sparkle x={150} y={100} delay={5.2} />
        <Sparkle x={750} y={120} delay={5.4} />
        <Sparkle x={130} y={350} delay={5.6} />
        <Sparkle x={770} y={380} delay={5.8} />
      </motion.g>
    </Scene>
  )
}

/**
 * TypewriterText - Renders text character by character
 */
function TypewriterText({ text, delay = 0, charDelay = 0.05 }) {
  return (
    <>
      {text.split('').map((char, i) => (
        <motion.tspan
          key={i}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: delay + (i * charDelay), duration: 0.05 }}
        >
          {char}
        </motion.tspan>
      ))}
    </>
  )
}

/**
 * Sparkle - Small decorative star/sparkle
 */
function Sparkle({ x, y, delay = 0 }) {
  return (
    <motion.g
      initial={{ opacity: 0, scale: 0 }}
      animate={{ opacity: [0, 1, 0.5, 1], scale: [0, 1.2, 0.9, 1] }}
      transition={{ delay, duration: 0.8, ease: 'easeOut' }}
    >
      <motion.path
        d={`M ${x} ${y-8} L ${x} ${y+8} M ${x-8} ${y} L ${x+8} ${y} M ${x-5} ${y-5} L ${x+5} ${y+5} M ${x+5} ${y-5} L ${x-5} ${y+5}`}
        stroke="#feca57"
        strokeWidth={2}
        strokeLinecap="round"
        animate={{ 
          rotate: [0, 15, -15, 0],
          scale: [1, 1.1, 1]
        }}
        transition={{
          duration: 3,
          repeat: Infinity,
          repeatType: 'reverse',
          ease: 'easeInOut'
        }}
        style={{ transformOrigin: `${x}px ${y}px` }}
      />
    </motion.g>
  )
}

export default CTAScene

