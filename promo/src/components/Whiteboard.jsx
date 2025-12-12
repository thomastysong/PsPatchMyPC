import { motion } from 'framer-motion'

const styles = {
  container: {
    width: '90vw',
    maxWidth: '1200px',
    height: '80vh',
    maxHeight: '700px',
    position: 'relative',
    borderRadius: '12px',
    overflow: 'hidden',
  },
  board: {
    width: '100%',
    height: '100%',
    background: 'linear-gradient(145deg, #2d3436 0%, #1e272e 100%)',
    borderRadius: '12px',
    border: '8px solid #4a3728',
    boxShadow: `
      inset 0 0 100px rgba(0,0,0,0.3),
      0 20px 60px rgba(0,0,0,0.5),
      0 0 0 2px rgba(255,255,255,0.05)
    `,
    position: 'relative',
    overflow: 'hidden',
  },
  // Wood frame effect
  frameTop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: '8px',
    background: 'linear-gradient(180deg, #5d4e37 0%, #4a3728 100%)',
    zIndex: 10,
  },
  frameBottom: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: '8px',
    background: 'linear-gradient(0deg, #3d2e1f 0%, #4a3728 100%)',
    zIndex: 10,
  },
  // Chalk dust texture
  chalkDust: {
    position: 'absolute',
    inset: 0,
    background: `
      radial-gradient(circle at 30% 40%, rgba(255,255,255,0.03) 0%, transparent 40%),
      radial-gradient(circle at 70% 60%, rgba(255,255,255,0.02) 0%, transparent 35%),
      radial-gradient(circle at 50% 80%, rgba(255,255,255,0.015) 0%, transparent 30%)
    `,
    pointerEvents: 'none',
  },
  content: {
    position: 'absolute',
    inset: '24px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
}

function Whiteboard({ children }) {
  return (
    <motion.div 
      style={styles.container}
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.6, ease: 'easeOut' }}
    >
      <div style={styles.board}>
        <div style={styles.frameTop} />
        <div style={styles.frameBottom} />
        <div style={styles.chalkDust} />
        <div style={styles.content}>
          {children}
        </div>
      </div>
    </motion.div>
  )
}

export default Whiteboard

