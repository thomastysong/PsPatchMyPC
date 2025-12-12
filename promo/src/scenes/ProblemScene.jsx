import { motion } from 'framer-motion'
import Scene from '../components/Scene'
import DrawnPath, { DrawnText, DrawnCircle, DrawnLine, DrawnRect } from '../components/DrawnPath'

/**
 * ProblemScene - Illustrates enterprise patching pain points
 * "Enterprise Patching is Broken" with visual representations
 */
function ProblemScene() {
  return (
    <Scene viewBox="0 0 900 500">
      {/* Main Title */}
      <DrawnText
        x={450}
        y={55}
        fontSize={42}
        fontWeight={700}
        delay={0.2}
        duration={1}
        fill="#ff6b6b"
      >
        Enterprise Patching is Broken
      </DrawnText>

      {/* Underline flourish */}
      <DrawnPath
        d="M 180 70 Q 450 85 720 70"
        delay={0.8}
        duration={0.6}
        stroke="#ff6b6b"
        strokeWidth={2}
      />

      {/* --- Pain Point 1: Manual Updates --- */}
      <g>
        {/* Frustrated admin icon */}
        <DrawnCircle cx={150} cy={180} r={30} delay={1.2} stroke="#feca57" strokeWidth={2.5} />
        {/* Face - tired eyes */}
        <DrawnLine x1={138} y1={175} x2={148} y2={175} delay={1.4} stroke="#feca57" strokeWidth={2} />
        <DrawnLine x1={152} y1={175} x2={162} y2={175} delay={1.4} stroke="#feca57" strokeWidth={2} />
        {/* Frown */}
        <DrawnPath d="M 140 192 Q 150 185 160 192" delay={1.5} stroke="#feca57" strokeWidth={2} />
        {/* Sweat drop */}
        <DrawnPath d="M 175 160 Q 180 170 175 180 Q 170 170 175 160" delay={1.6} stroke="#54a0ff" strokeWidth={1.5} fill="none" />
        
        {/* Label */}
        <DrawnText x={150} y={240} fontSize={20} delay={1.7} fill="#feca57">
          Manual Updates
        </DrawnText>
        <DrawnText x={150} y={262} fontSize={16} delay={1.9} fill="#aaa">
          "Did everyone reboot?"
        </DrawnText>
      </g>

      {/* --- Pain Point 2: Scattered Computers --- */}
      <g>
        {/* Computer icons scattered */}
        <DrawnRect x={320} y={150} width={40} height={30} delay={2.1} stroke="#54a0ff" />
        <DrawnLine x1={340} y1={180} x2={340} y2={190} delay={2.2} stroke="#54a0ff" />
        <DrawnLine x1={325} y1={190} x2={355} y2={190} delay={2.3} stroke="#54a0ff" />
        
        <DrawnRect x={400} y={165} width={35} height={25} delay={2.4} stroke="#54a0ff" />
        <DrawnLine x1={417} y1={190} x2={417} y2={198} delay={2.5} stroke="#54a0ff" />
        
        <DrawnRect x={365} y={130} width={30} height={22} delay={2.6} stroke="#54a0ff" />
        
        {/* Question marks */}
        <DrawnText x={350} y={125} fontSize={18} delay={2.7} fill="#ff6b6b">?</DrawnText>
        <DrawnText x={435} y={165} fontSize={16} delay={2.8} fill="#ff6b6b">?</DrawnText>
        <DrawnText x={315} y={148} fontSize={14} delay={2.9} fill="#ff6b6b">?</DrawnText>
        
        {/* Label */}
        <DrawnText x={380} y={240} fontSize={20} delay={3.0} fill="#54a0ff">
          No Visibility
        </DrawnText>
        <DrawnText x={380} y={262} fontSize={16} delay={3.2} fill="#aaa">
          "Which machines need updates?"
        </DrawnText>
      </g>

      {/* --- Pain Point 3: User Interruptions --- */}
      <g>
        {/* Angry user popup */}
        <DrawnRect x={560} y={140} width={100} height={60} delay={3.4} stroke="#ff9f43" strokeWidth={2} />
        {/* X button */}
        <DrawnLine x1={640} y1={148} x2={650} y2={158} delay={3.5} stroke="#ff6b6b" strokeWidth={2} />
        <DrawnLine x1={650} y1={148} x2={640} y2={158} delay={3.5} stroke="#ff6b6b" strokeWidth={2} />
        {/* Popup lines */}
        <DrawnLine x1={570} y1={160} x2={620} y2={160} delay={3.6} stroke="#ff9f43" />
        <DrawnLine x1={570} y1={172} x2={640} y2={172} delay={3.7} stroke="#ff9f43" />
        <DrawnLine x1={570} y1={184} x2={600} y2={184} delay={3.8} stroke="#ff9f43" />
        
        {/* Frustrated click marks */}
        <DrawnText x={680} y={150} fontSize={24} delay={3.9} fill="#ff6b6b">!</DrawnText>
        
        {/* Label */}
        <DrawnText x={610} y={240} fontSize={20} delay={4.0} fill="#ff9f43">
          User Interruptions
        </DrawnText>
        <DrawnText x={610} y={262} fontSize={16} delay={4.2} fill="#aaa">
          "I was in a meeting!"
        </DrawnText>
      </g>

      {/* --- Pain Point 4: Compliance Gaps --- */}
      <g>
        {/* Shield with crack */}
        <DrawnPath 
          d="M 790 130 L 820 145 L 820 180 Q 820 210 790 225 Q 760 210 760 180 L 760 145 Z"
          delay={4.4}
          stroke="#ee5a24"
          strokeWidth={2.5}
        />
        {/* Crack in shield */}
        <DrawnPath 
          d="M 790 145 L 795 165 L 785 175 L 792 195"
          delay={4.6}
          stroke="#ff6b6b"
          strokeWidth={2}
        />
        
        {/* Warning triangle */}
        <DrawnPath 
          d="M 820 155 L 840 190 L 800 190 Z"
          delay={4.8}
          stroke="#ff6b6b"
          strokeWidth={2}
        />
        <DrawnText x={820} y={185} fontSize={16} delay={5.0} fill="#ff6b6b">!</DrawnText>
        
        {/* Label */}
        <DrawnText x={800} y={250} fontSize={20} delay={5.1} fill="#ee5a24">
          Compliance Gaps
        </DrawnText>
        <DrawnText x={800} y={272} fontSize={16} delay={5.3} fill="#aaa">
          "Audit next week..."
        </DrawnText>
      </g>

      {/* Bottom connector line */}
      <DrawnPath
        d="M 150 290 Q 300 340 450 320 Q 600 300 800 290"
        delay={5.5}
        duration={1}
        stroke="#666"
        strokeWidth={1.5}
        opacity={0.5}
      />

      {/* Summary pain */}
      <motion.g
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 6, duration: 0.8 }}
      >
        <DrawnRect x={280} y={350} width={340} height={80} rx={8} delay={6.2} stroke="#ff6b6b" strokeWidth={2} />
        <DrawnText x={450} y={385} fontSize={22} delay={6.5} fill="#ff6b6b">
          Result: Security Risk + Unhappy Users
        </DrawnText>
        <DrawnText x={450} y={415} fontSize={18} delay={6.8} fill="#aaa">
          There has to be a better way...
        </DrawnText>
      </motion.g>

      {/* Dots trailing off suggesting transition */}
      <DrawnText x={600} y={450} fontSize={28} delay={7.2} fill="#666">. . .</DrawnText>
    </Scene>
  )
}

export default ProblemScene

