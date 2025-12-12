import { motion } from 'framer-motion'

/**
 * DrawnPath - Animates SVG paths with a hand-drawing effect
 * Uses stroke-dasharray/dashoffset technique to reveal paths progressively
 */
function DrawnPath({ 
  d,                    // SVG path data
  delay = 0,            // Animation delay in seconds
  duration = 1.5,       // Drawing duration in seconds
  stroke = '#f5f5f5',   // Chalk color
  strokeWidth = 2,      // Line thickness
  fill = 'none',        // Fill color
  opacity = 0.9,        // Final opacity
  wobble = true,        // Add slight hand-drawn wobble
  ...props 
}) {
  // Add subtle variation to make it feel hand-drawn
  const wobbleFilter = wobble ? 'url(#chalkWobble)' : 'none'

  return (
    <motion.path
      d={d}
      fill={fill}
      stroke={stroke}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      filter={wobbleFilter}
      initial={{ 
        pathLength: 0,
        opacity: 0 
      }}
      animate={{ 
        pathLength: 1,
        opacity: opacity 
      }}
      transition={{
        pathLength: { 
          delay, 
          duration, 
          ease: [0.43, 0.13, 0.23, 0.96] // Custom easing for natural draw feel
        },
        opacity: { 
          delay, 
          duration: 0.3 
        }
      }}
      style={{
        strokeDasharray: 1,
        strokeDashoffset: 1,
      }}
      {...props}
    />
  )
}

/**
 * DrawnText - Animates text with chalk-like appearance
 */
export function DrawnText({
  children,
  x = 0,
  y = 0,
  delay = 0,
  duration = 0.8,
  fontSize = 24,
  fill = '#f5f5f5',
  textAnchor = 'middle',
  fontFamily = "'Caveat', cursive",
  fontWeight = 600,
  ...props
}) {
  return (
    <motion.text
      x={x}
      y={y}
      fontSize={fontSize}
      fill={fill}
      textAnchor={textAnchor}
      fontFamily={fontFamily}
      fontWeight={fontWeight}
      filter="url(#chalkTexture)"
      initial={{ opacity: 0, y: y - 10 }}
      animate={{ opacity: 0.95, y }}
      transition={{
        delay,
        duration,
        ease: 'easeOut'
      }}
      {...props}
    >
      {children}
    </motion.text>
  )
}

/**
 * DrawnCircle - Animated circle with hand-drawn effect
 */
export function DrawnCircle({
  cx,
  cy,
  r,
  delay = 0,
  duration = 1,
  stroke = '#f5f5f5',
  strokeWidth = 2,
  fill = 'none',
  ...props
}) {
  return (
    <motion.circle
      cx={cx}
      cy={cy}
      r={r}
      fill={fill}
      stroke={stroke}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      filter="url(#chalkWobble)"
      initial={{ pathLength: 0, opacity: 0 }}
      animate={{ pathLength: 1, opacity: 0.9 }}
      transition={{
        pathLength: { delay, duration, ease: 'easeInOut' },
        opacity: { delay, duration: 0.3 }
      }}
      style={{
        strokeDasharray: 1,
        strokeDashoffset: 1,
      }}
      {...props}
    />
  )
}

/**
 * DrawnLine - Simple animated line
 */
export function DrawnLine({
  x1, y1, x2, y2,
  delay = 0,
  duration = 0.8,
  stroke = '#f5f5f5',
  strokeWidth = 2,
  ...props
}) {
  return (
    <motion.line
      x1={x1}
      y1={y1}
      x2={x2}
      y2={y2}
      stroke={stroke}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      filter="url(#chalkWobble)"
      initial={{ pathLength: 0, opacity: 0 }}
      animate={{ pathLength: 1, opacity: 0.9 }}
      transition={{
        pathLength: { delay, duration, ease: 'easeOut' },
        opacity: { delay, duration: 0.2 }
      }}
      style={{
        strokeDasharray: 1,
        strokeDashoffset: 1,
      }}
      {...props}
    />
  )
}

/**
 * DrawnRect - Animated rectangle
 */
export function DrawnRect({
  x, y, width, height,
  rx = 4,
  delay = 0,
  duration = 1.2,
  stroke = '#f5f5f5',
  strokeWidth = 2,
  fill = 'none',
  ...props
}) {
  return (
    <motion.rect
      x={x}
      y={y}
      width={width}
      height={height}
      rx={rx}
      fill={fill}
      stroke={stroke}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      filter="url(#chalkWobble)"
      initial={{ pathLength: 0, opacity: 0 }}
      animate={{ pathLength: 1, opacity: 0.9 }}
      transition={{
        pathLength: { delay, duration, ease: 'easeInOut' },
        opacity: { delay, duration: 0.3 }
      }}
      style={{
        strokeDasharray: 1,
        strokeDashoffset: 1,
      }}
      {...props}
    />
  )
}

/**
 * ChalkFilters - SVG filter definitions for chalk-like effects
 * Include this once in your SVG
 */
export function ChalkFilters() {
  return (
    <defs>
      {/* Slight displacement for hand-drawn wobble */}
      <filter id="chalkWobble" x="-5%" y="-5%" width="110%" height="110%">
        <feTurbulence type="fractalNoise" baseFrequency="0.04" numOctaves="2" result="noise" />
        <feDisplacementMap in="SourceGraphic" in2="noise" scale="1.5" xChannelSelector="R" yChannelSelector="G" />
      </filter>
      
      {/* Texture for chalk-like text */}
      <filter id="chalkTexture" x="-10%" y="-10%" width="120%" height="120%">
        <feTurbulence type="fractalNoise" baseFrequency="0.5" numOctaves="3" result="noise" />
        <feComposite in="SourceGraphic" in2="noise" operator="in" />
      </filter>

      {/* Glow effect for emphasis */}
      <filter id="chalkGlow" x="-20%" y="-20%" width="140%" height="140%">
        <feGaussianBlur stdDeviation="2" result="blur" />
        <feMerge>
          <feMergeNode in="blur" />
          <feMergeNode in="SourceGraphic" />
        </feMerge>
      </filter>
    </defs>
  )
}

export default DrawnPath

