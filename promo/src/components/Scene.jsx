import { motion } from 'framer-motion'
import { ChalkFilters } from './DrawnPath'

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.15,
      delayChildren: 0.2,
    }
  },
  exit: {
    opacity: 0,
    transition: {
      duration: 0.5,
      ease: 'easeIn'
    }
  }
}

/**
 * Scene - Base wrapper for animation scenes
 * Provides SVG canvas with filters and staggered animation orchestration
 */
function Scene({ children, viewBox = "0 0 900 500" }) {
  return (
    <motion.svg
      viewBox={viewBox}
      style={{
        width: '100%',
        height: '100%',
        overflow: 'visible',
      }}
      variants={containerVariants}
      initial="hidden"
      animate="visible"
      exit="exit"
    >
      <ChalkFilters />
      {children}
    </motion.svg>
  )
}

export default Scene

