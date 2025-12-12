import { useState, useEffect } from 'react'
import { AnimatePresence } from 'framer-motion'
import Whiteboard from './components/Whiteboard'
import ProblemScene from './scenes/ProblemScene'
import SolutionScene from './scenes/SolutionScene'
import CTAScene from './scenes/CTAScene'

const styles = {
  app: {
    width: '100vw',
    height: '100vh',
    background: 'linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f0f23 100%)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
    overflow: 'hidden',
  },
  // Chalkboard texture overlay
  texture: {
    position: 'absolute',
    inset: 0,
    background: `
      radial-gradient(ellipse at 20% 30%, rgba(255,255,255,0.02) 0%, transparent 50%),
      radial-gradient(ellipse at 80% 70%, rgba(255,255,255,0.015) 0%, transparent 50%)
    `,
    pointerEvents: 'none',
  },
  controls: {
    position: 'absolute',
    bottom: '20px',
    left: '50%',
    transform: 'translateX(-50%)',
    display: 'flex',
    gap: '12px',
    zIndex: 100,
  },
  button: {
    padding: '10px 20px',
    background: 'rgba(255,255,255,0.1)',
    border: '2px solid rgba(255,255,255,0.3)',
    borderRadius: '8px',
    color: '#fff',
    fontFamily: "'Architects Daughter', cursive",
    fontSize: '14px',
    cursor: 'pointer',
    transition: 'all 0.2s ease',
  },
}

function App() {
  const [currentScene, setCurrentScene] = useState(0)
  const [isPlaying, setIsPlaying] = useState(true)

  // Scene timing
  const sceneDurations = [8000, 10000, 6000] // Problem: 8s, Solution: 10s, CTA: 6s

  useEffect(() => {
    if (!isPlaying) return

    const timer = setTimeout(() => {
      if (currentScene < 2) {
        setCurrentScene(prev => prev + 1)
      } else {
        setIsPlaying(false)
      }
    }, sceneDurations[currentScene])

    return () => clearTimeout(timer)
  }, [currentScene, isPlaying])

  const handleRestart = () => {
    setCurrentScene(0)
    setIsPlaying(true)
  }

  const handleSkip = () => {
    if (currentScene < 2) {
      setCurrentScene(prev => prev + 1)
    }
  }

  return (
    <div style={styles.app}>
      <div style={styles.texture} />
      
      <Whiteboard>
        <AnimatePresence mode="wait">
          {currentScene === 0 && <ProblemScene key="problem" />}
          {currentScene === 1 && <SolutionScene key="solution" />}
          {currentScene === 2 && <CTAScene key="cta" />}
        </AnimatePresence>
      </Whiteboard>

      <div style={styles.controls}>
        <button 
          style={styles.button}
          onClick={handleRestart}
          onMouseEnter={e => e.target.style.background = 'rgba(255,255,255,0.2)'}
          onMouseLeave={e => e.target.style.background = 'rgba(255,255,255,0.1)'}
        >
          ↺ Restart
        </button>
        {currentScene < 2 && (
          <button 
            style={styles.button}
            onClick={handleSkip}
            onMouseEnter={e => e.target.style.background = 'rgba(255,255,255,0.2)'}
            onMouseLeave={e => e.target.style.background = 'rgba(255,255,255,0.1)'}
          >
            Skip →
          </button>
        )}
      </div>
    </div>
  )
}

export default App

