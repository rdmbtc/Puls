"use client"

import { useRef, useEffect, useCallback } from "react"

// ── SVG Shape ────────────────────────────────────────────
const SVG_PATH = `M318.124,491.209c-3.063,0-5.963-1.834-7.173-4.851c-1.589-3.961,0.333-8.459,4.293-10.048       c30.784-12.351,54.872-31.609,71.595-57.237c13.459-20.627,22.286-45.484,26.233-73.882       c6.791-48.844-3.302-91.325-3.405-91.749c-1.006-4.147,1.54-8.324,5.687-9.33c4.15-1.008,8.324,1.539,9.331,5.686       c0.448,1.845,10.885,45.792,3.694,97.521c-9.656,69.458-46.788,119.021-107.38,143.333       C320.056,491.03,319.082,491.209,318.124,491.209z M428.204,191.055c4.255,26.707,0.114,63.715-11.961,65.639         c-12.075,1.924-27.511-31.965-31.766-58.672c-4.255-26.707,4.283-36.118,16.357-38.041         C412.91,158.057,423.949,164.349,428.204,191.055z M416.241,256.688c-2.81,0.451-5.809-1.046-8.811-3.947         c5.958-12.568,7.449-38.173,4.279-58.072c-3.368-21.12-10.979-29.467-19.994-31.089c2.625-1.93,5.73-3.069,9.12-3.602         c12.075-1.917,23.117,4.37,27.371,31.074C432.459,217.767,428.317,254.771,416.241,256.688z M419.261,357.948c-5.938,2.956-15.975-3.85-25.836-14.552         c-8.316-9.037-16.515-20.838-22.034-31.917c-12.057-24.218-6.729-35.745,4.219-41.2c10.636-5.293,22.667-2.889,34.407,19.49         c0.344,0.637,0.675,1.294,1.012,1.973C423.077,315.948,430.209,352.493,419.261,357.948z M419.261,357.948c-5.938,2.956-15.975-3.85-25.836-14.552c0.17-4.604,0.885-9.71,2.142-15.297         c2.794-12.452,8.082-26.4,14.449-38.331c0.344,0.637,0.675,1.294,1.012,1.973         C423.077,315.948,430.209,352.493,419.261,357.948z M425.822,292.275c-13.78,23.27-23.541,59.207-13.02,65.437         c10.521,6.23,37.34-19.606,51.119-42.876c13.78-23.27,9.302-35.161-1.219-41.391S439.601,269.006,425.822,292.275z M463.922,314.839c-13.783,23.263-40.595,49.101-51.125,42.872         c-2.454-1.444-3.795-4.509-4.251-8.647c12.611-5.76,30.229-24.616,40.544-42.029c10.861-18.35,10.378-29.617,4.532-36.62         c3.17,0.222,6.206,1.323,9.082,3.026C473.222,279.68,477.697,291.564,463.922,314.839z M373.157,460.499c-6.626,0.376-13.155-9.847-17.989-23.579         c-4.083-11.576-6.95-25.668-7.655-38.018c-1.527-26.996,7.924-35.5,20.13-36.187c11.877-0.669,21.984,6.291,23.935,31.502         c0.058,0.717,0.104,1.443,0.147,2.191C393.24,423.412,385.366,459.802,373.157,460.499z M373.157,460.499c-6.626,0.376-13.155-9.847-17.989-23.579         c1.964-4.168,4.633-8.571,7.996-13.21c7.491-10.34,17.854-21.055,28.414-29.494c0.058,0.717,0.104,1.443,0.147,2.191         C393.24,423.412,385.366,459.802,373.157,460.499z M405.103,402.742c-21.844,15.943-44.996,45.111-37.787,54.987         c7.208,9.876,42.046-3.279,63.891-19.222s22.423-28.636,15.215-38.513C439.212,390.119,426.947,386.8,405.103,402.742z M431.207,438.504c-21.848,15.945-56.681,29.1-63.891,19.224         c-1.113-1.523-1.501-3.517-1.275-5.848c14.092-1.573,35.562-11.308,50.755-22.389c21.273-15.524,22.379-27.969,15.77-37.739         c6.033,0.455,10.498,3.635,13.852,8.24C453.628,409.868,453.052,422.57,431.207,438.504z M193.876,491.209c-0.958,0-1.931-0.179-2.875-0.557       c-60.592-24.312-97.723-73.875-107.38-143.333c-7.191-51.729,3.246-95.676,3.694-97.521c1.006-4.147,5.183-6.699,9.33-5.686       c4.145,1.005,6.691,5.18,5.688,9.325l0,0c-0.103,0.428-10.236,43.316-3.344,92.2c3.992,28.309,12.843,53.088,26.308,73.646       c16.717,25.523,40.759,44.71,71.458,57.027c3.96,1.59,5.882,6.088,4.293,10.048       C199.839,489.375,196.939,491.209,193.876,491.209z M83.796,191.055c-4.255,26.707-0.114,63.715,11.961,65.639        c12.075,1.924,27.511-31.965,31.766-58.672c4.255-26.707-4.283-36.118-16.357-38.041        C99.09,158.057,88.051,164.349,83.796,191.055z M127.522,198.026c-4.254,26.704-19.687,60.59-31.764,58.662        c-2.965-0.467-5.455-3.052-7.451-7.095c9.68-9.876,19.236-34.089,22.443-54.212c3.21-20.168-0.871-30.478-8.26-35.125        c2.765-0.727,5.687-0.753,8.675-0.279C123.242,161.906,131.775,171.311,127.522,198.026z M92.739,357.948c5.938,2.956,15.975-3.85,25.836-14.552        c8.316-9.037,16.515-20.838,22.034-31.917c12.057-24.218,6.729-35.745-4.219-41.2c-10.636-5.293-22.667-2.889-34.407,19.49        c-0.344,0.637-0.675,1.294-1.012,1.973C88.923,315.948,81.791,352.493,92.739,357.948z M140.609,311.479c-5.52,11.079-13.718,22.88-22.034,31.917        c-9.861,10.702-19.897,17.508-25.836,14.552c-1.61-0.804-2.841-2.295-3.707-4.306c4.071-2.698,8.491-6.686,12.874-11.44        c8.316-9.037,16.515-20.838,22.034-31.917c11.865-23.826,6.892-35.371-3.692-40.924c5.571-2.396,11.026-1.629,16.141,0.918        C147.337,275.734,152.666,287.261,140.609,311.479z M92.739,357.948c5.938,2.956,15.975-3.85,25.836-14.552c-0.17-4.604-0.885-9.71-2.142-15.297        c-2.794-12.452-8.082-26.4-14.449-38.331c-0.344,0.637-0.675,1.294-1.012,1.973C88.923,315.948,81.791,352.493,92.739,357.948        z M86.178,292.275c13.78,23.27,23.541,59.207,13.02,65.437s-37.34-19.606-51.119-42.876        c-13.78-23.27-9.302-35.161,1.219-41.391S72.399,269.006,86.178,292.275z M99.202,357.711c-2.65,1.566-6.332,1.106-10.58-0.843c1.871-13.448-6.433-39.32-17.183-57.472        c-9.803-16.546-18.985-22.226-27.257-21.888c1.44-1.581,3.173-2.92,5.113-4.067c10.519-6.228,23.106-4.433,36.878,18.831        C99.958,315.547,109.721,351.484,99.202,357.711z M138.843,460.499c6.626,0.376,13.155-9.847,17.989-23.579        c4.083-11.576,6.95-25.668,7.655-38.018c1.527-26.996-7.924-35.5-20.13-36.187c-11.877-0.669-21.984,6.291-23.935,31.502        c-0.058,0.717-0.104,1.443-0.147,2.191C118.76,423.412,126.634,459.802,138.843,460.499z M164.487,398.902c-0.705,12.351-3.572,26.443-7.655,38.018        c-4.834,13.732-11.364,23.955-17.989,23.579c-3.121-0.179-5.957-2.692-8.429-6.781c3.495-4.239,6.737-10.836,9.439-18.525        c4.083-11.576,6.95-25.668,7.655-38.018c1.109-19.558-3.555-29.417-10.844-33.615c2.423-0.754,5.014-0.993,7.694-0.845        C156.563,363.402,166.014,371.907,164.487,398.902z M138.843,460.499c6.626,0.376,13.155-9.847,17.989-23.579c-1.964-4.168-4.633-8.57-7.996-13.21        c-7.491-10.34-17.854-21.055-28.414-29.494c-0.058,0.717-0.104,1.443-0.147,2.191        C118.76,423.412,126.634,459.802,138.843,460.499z M106.897,402.742c21.844,15.943,44.996,45.111,37.787,54.987        c-7.208,9.876-42.046-3.279-63.891-19.222s-22.423-28.636-15.215-38.513S85.053,386.8,106.897,402.742z M144.685,457.729c-2.304,3.158-7.437,3.965-14.068,3.068        c0.22-12.385-19.956-36.555-39.118-50.537c-10.488-7.658-18.765-10.865-25.334-11.044c7.277-9.257,19.467-11.993,40.729,3.533        C128.739,418.683,151.895,447.853,144.685,457.729z M365.314,113.605L263.718,3.383c-4.157-4.51-11.279-4.51-15.436,0L146.686,113.605   c-6.199,6.726-1.429,17.611,7.718,17.611h36.594v219.175c0,5.797,4.7,10.497,10.497,10.497h109.009   c5.797,0,10.497-4.7,10.497-10.497V131.216h36.594C366.743,131.216,371.513,120.331,365.314,113.605z M357.596,131.214h-23.797c9.148,0,13.918-10.879,7.716-17.606L244.101,7.912l4.183-4.533   c4.152-4.502,11.281-4.502,15.432,0l101.596,110.229C371.514,120.336,366.744,131.214,357.596,131.214z M321.004,131.214v219.181c0,5.792-4.695,10.487-10.487,10.487H287.06   c5.8,0,10.498-4.698,10.498-10.487v-213c0-3.414,2.767-6.181,6.181-6.181H321.004z M190.999,399.408v25.51c0,5.797,4.7,10.497,10.497,10.497h109.009    c5.797,0,10.497-4.7,10.497-10.497v-25.51c0-5.797-4.7-10.497-10.497-10.497H201.495    C195.698,388.911,190.999,393.611,190.999,399.408z M321.004,399.411v25.507c0,5.8-4.698,10.497-10.498,10.497H287.06    c5.8,0,10.498-4.697,10.498-10.497v-25.507c0-5.8-4.698-10.497-10.498-10.497h23.447    C316.307,388.914,321.004,393.612,321.004,399.411z M190.999,475.993v25.51c0,5.797,4.7,10.497,10.497,10.497h109.009    c5.797,0,10.497-4.7,10.497-10.497v-25.51c0-5.797-4.7-10.497-10.497-10.497H201.495    C195.698,465.497,190.999,470.196,190.999,475.993z M321.004,475.995v25.507c0,5.8-4.698,10.497-10.498,10.497H287.06    c5.8,0,10.498-4.698,10.498-10.497v-25.507c0-5.8-4.698-10.498-10.498-10.498h23.447    C316.307,465.497,321.004,470.195,321.004,475.995z`
const SVG_WIDTH = 512
const SVG_HEIGHT = 512

// ── Config ──────────────────────────────────────────────
interface ParticlesConfig {
  gridSize: number
  attractRadius: number
  repelRadius: number
  attractStrength: number
  repelStrength: number
  flickerChance: number
  breatheIntensity: number
  animDuration: number
}

const DEFAULT_CONFIG: ParticlesConfig = {
  "gridSize": 1.5,
  "attractRadius": 106,
  "repelRadius": 100,
  "attractStrength": 0.06,
  "repelStrength": 1.2,
  "flickerChance": 0.11,
  "breatheIntensity": 0.08,
  "animDuration": 3000
}

// ── SVG Utilities ───────────────────────────────────────

// ── Particles Shader ──────────────────────────────────────
interface Particle {
  x: number
  y: number
  vx: number
  vy: number
  targetX: number
  targetY: number
  startX: number
  startY: number
  jitterX: number
  jitterY: number
  delay: number
  alpha: number
  flickerPhase: number
  flickerSpeed: number
  isFlickering: boolean
  flickerStart: number
  density: number
}

function easeOutQuart(t: number): number {
  return 1 - Math.pow(1 - t, 4)
}

function easeInOutCubic(t: number): number {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2
}

interface Props {
  config: ParticlesConfig
  playing?: boolean
  resetKey?: number
  svgScale?: number
  theme?: "light" | "dark"
  svgPath?: string
  svgWidth?: number
  svgHeight?: number
}

export default function ParticlesShader({ config, playing = true, resetKey = 0, svgScale = 1, theme = "dark", svgPath = SVG_PATH, svgWidth = SVG_WIDTH, svgHeight = SVG_HEIGHT }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const particlesRef = useRef<Particle[]>([])
  const startTimeRef = useRef<number | null>(null)
  const rafRef = useRef<number>(0)
  const mouseRef = useRef<{ x: number; y: number; active: boolean }>({ x: 0, y: 0, active: false })
  const configRef = useRef(config)
  const playingRef = useRef(playing)
  const pausedAtRef = useRef<number | null>(null)
  const pauseOffsetRef = useRef(0)
  const themeRef = useRef(theme)

  configRef.current = config
  playingRef.current = playing
  themeRef.current = theme

  const init = useCallback(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const dpr = window.devicePixelRatio || 1
    const width = window.innerWidth
    const height = window.innerHeight

    canvas.width = width * dpr
    canvas.height = height * dpr
    canvas.style.width = `${width}px`
    canvas.style.height = `${height}px`

    const ctx = canvas.getContext("2d")
    if (!ctx) return
    ctx.scale(dpr, dpr)

    const cfg = configRef.current
    const points = fillSVGPath(svgPath, cfg.gridSize, svgWidth, svgHeight)
    const { scale, offsetX, offsetY } = getLogoTransform(width, height, svgScale, svgWidth, svgHeight)

    const centerX = width / 2
    const centerY = height / 2

    const filteredPoints = points.filter((point) => {
      const edgeProb = point.edgeDist <= 2 ? 1 : 0.6
      const logoCenter = { x: svgWidth / 2, y: svgHeight / 2 }
      const distFromCenter = Math.sqrt(
        Math.pow(point.x - logoCenter.x, 2) + Math.pow(point.y - logoCenter.y, 2)
      )
      const maxDist = Math.sqrt(logoCenter.x * logoCenter.x + logoCenter.y * logoCenter.y)
      const normalizedDist = distFromCenter / maxDist

      // Smooth cosine interpolation avoids a visible circular boundary
      const densityFactor = 0.65 + 0.25 * Math.cos(normalizedDist * Math.PI)

      return Math.random() < edgeProb * densityFactor
    })

    const particles: Particle[] = filteredPoints.map((point) => {
      const targetX = point.x * scale + offsetX
      const targetY = point.y * scale + offsetY

      const jitterAmount = 1.5 + Math.random() * 2
      const jitterX = (Math.random() - 0.5) * jitterAmount
      const jitterY = (Math.random() - 0.5) * jitterAmount

      const angle = Math.random() * Math.PI * 2
      const minRadius = Math.max(width, height) * 0.6
      const maxRadius = Math.max(width, height) * 1.2
      const spawnRadius = minRadius + Math.random() * (maxRadius - minRadius)

      const angleJitter = (Math.random() - 0.5) * 0.5
      const finalAngle = angle + angleJitter

      const startX = centerX + Math.cos(finalAngle) * spawnRadius + (Math.random() - 0.5) * 200
      const startY = centerY + Math.sin(finalAngle) * spawnRadius + (Math.random() - 0.5) * 200

      const distFromCenterVal = Math.sqrt(
        Math.pow(targetX - centerX, 2) + Math.pow(targetY - centerY, 2)
      )
      const maxDistVal = Math.sqrt(
        Math.pow(width / 2, 2) + Math.pow(height / 2, 2)
      )
      const normalizedDist = distFromCenterVal / maxDistVal

      const baseDelay = normalizedDist * 0.6
      const randomDelay = Math.random() * 0.25
      const delay = baseDelay + randomDelay

      const isFlickering = Math.random() < cfg.flickerChance

      return {
        x: startX,
        y: startY,
        vx: 0,
        vy: 0,
        targetX: targetX + jitterX,
        targetY: targetY + jitterY,
        startX,
        startY,
        jitterX,
        jitterY,
        delay,
        alpha: 0,
        flickerPhase: Math.random() * Math.PI * 2,
        flickerSpeed: 0.5 + Math.random() * 2,
        isFlickering,
        flickerStart: 4000 + Math.random() * 2000,
        density: point.edgeDist / 10,
      }
    })

    particlesRef.current = particles
    startTimeRef.current = null
  }, [svgScale, svgPath, svgWidth, svgHeight])

  useEffect(() => {
    init()
    window.addEventListener("resize", init)
    return () => window.removeEventListener("resize", init)
  }, [init])

  useEffect(() => {
    if (resetKey > 0) {
      startTimeRef.current = null
      pauseOffsetRef.current = 0
      pausedAtRef.current = null
      init()
    }
  }, [resetKey, init])

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      mouseRef.current = { x: e.clientX, y: e.clientY, active: true }
    }
    const handleMouseLeave = () => {
      mouseRef.current.active = false
    }
    const handleTouchStart = (e: TouchEvent) => {
      if ((e.target as Element)?.closest?.("[data-controls-panel]")) return
      const touch = e.touches[0]
      if (touch) mouseRef.current = { x: touch.clientX, y: touch.clientY, active: true }
    }
    const handleTouchMove = (e: TouchEvent) => {
      if ((e.target as Element)?.closest?.("[data-controls-panel]")) return
      const touch = e.touches[0]
      if (touch) mouseRef.current = { x: touch.clientX, y: touch.clientY, active: true }
    }
    const handleTouchEnd = () => {
      mouseRef.current.active = false
    }

    window.addEventListener("mousemove", handleMouseMove)
    window.addEventListener("mouseleave", handleMouseLeave)
    window.addEventListener("touchstart", handleTouchStart, { passive: true })
    window.addEventListener("touchmove", handleTouchMove, { passive: true })
    window.addEventListener("touchend", handleTouchEnd)

    return () => {
      window.removeEventListener("mousemove", handleMouseMove)
      window.removeEventListener("mouseleave", handleMouseLeave)
      window.removeEventListener("touchstart", handleTouchStart)
      window.removeEventListener("touchmove", handleTouchMove)
      window.removeEventListener("touchend", handleTouchEnd)
    }
  }, [])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext("2d")
    if (!ctx) return

    const animate = (timestamp: number) => {
      if (startTimeRef.current === null) {
        startTimeRef.current = timestamp
      }

      if (!playingRef.current) {
        pausedAtRef.current = timestamp
        rafRef.current = requestAnimationFrame(animate)
        return
      }

      if (pausedAtRef.current !== null) {
        pauseOffsetRef.current += timestamp - pausedAtRef.current
        pausedAtRef.current = null
      }

      const cfg = configRef.current
      const elapsed = timestamp - startTimeRef.current - pauseOffsetRef.current
      const duration = cfg.animDuration
      const globalProgress = Math.min(elapsed / duration, 1)

      const dpr = window.devicePixelRatio || 1
      const width = canvas.width / dpr
      const height = canvas.height / dpr

      const isLight = themeRef.current === "light"
      ctx.fillStyle = isLight ? "#f5f5f5" : "#000"
      ctx.fillRect(0, 0, width, height)

      const mouse = mouseRef.current
      const particles = particlesRef.current

      for (let i = 0; i < particles.length; i++) {
        const p = particles[i]

        const particleProgress = Math.max(0, Math.min(1, (globalProgress - p.delay) / (1 - p.delay)))
        const easedProgress = easeOutQuart(particleProgress)

        const baseX = p.startX + (p.targetX - p.startX) * easedProgress
        const baseY = p.startY + (p.targetY - p.startY) * easedProgress

        if (mouse.active && particleProgress > 0.3) {
          const dx = p.x - mouse.x
          const dy = p.y - mouse.y
          const dist = Math.sqrt(dx * dx + dy * dy)

          if (dist < cfg.repelRadius && dist > 0) {
            const force = (1 - dist / cfg.repelRadius) * cfg.repelStrength
            const pushX = (dx / dist) * force * cfg.repelRadius
            const pushY = (dy / dist) * force * cfg.repelRadius
            p.vx += pushX * 0.15
            p.vy += pushY * 0.15
          } else if (dist < cfg.attractRadius && dist > 0) {
            const normalizedDist = (dist - cfg.repelRadius) / (cfg.attractRadius - cfg.repelRadius)
            const force = (1 - normalizedDist) * cfg.attractStrength
            const pullX = -(dx / dist) * force * (cfg.attractRadius - cfg.repelRadius)
            const pullY = -(dy / dist) * force * (cfg.attractRadius - cfg.repelRadius)
            p.vx += pullX * 0.08
            p.vy += pullY * 0.08
          }
        }

        const distToTarget = Math.sqrt(Math.pow(baseX - p.x, 2) + Math.pow(baseY - p.y, 2))
        const maxReturnDist = 300
        const normalizedDist = Math.min(distToTarget / maxReturnDist, 1)
        const easeInFactor = normalizedDist * normalizedDist * normalizedDist
        const returnStrength = 0.008 + easeInFactor * 0.12

        p.vx += (baseX - p.x) * returnStrength
        p.vy += (baseY - p.y) * returnStrength

        const dampingFactor = 0.92 - easeInFactor * 0.08
        p.vx *= dampingFactor
        p.vy *= dampingFactor

        p.x += p.vx
        p.y += p.vy

        let alpha = Math.min(1, particleProgress * 2)

        if (p.isFlickering && elapsed > p.flickerStart && particleProgress >= 1) {
          const flickerTime = elapsed - p.flickerStart
          const flickerCycle = Math.sin(flickerTime * 0.003 * p.flickerSpeed + p.flickerPhase)

          if (flickerCycle < -0.7) {
            const fadeProgress = (flickerCycle + 1) / 0.3
            alpha = easeInOutCubic(fadeProgress) * 0.3
          } else if (flickerCycle < -0.4) {
            alpha = 0.3 + (flickerCycle + 0.7) / 0.3 * 0.7
          }
        }

        if (particleProgress >= 1) {
          const breathe = Math.sin(elapsed * 0.001 + p.flickerPhase) * cfg.breatheIntensity
          alpha = Math.max(0.2, Math.min(1, alpha + breathe))
        }

        p.alpha = alpha

        if (isLight) {
          const boosted = Math.min(1, p.alpha * 1.4 + 0.1)
          ctx.fillStyle = `rgba(0, 0, 0, ${boosted})`
          const px = Math.round(p.x)
          const py = Math.round(p.y)
          ctx.fillRect(px, py, 2, 2)
        } else {
          ctx.fillStyle = `rgba(255, 255, 255, ${p.alpha})`
          ctx.fillRect(Math.round(p.x), Math.round(p.y), 1, 1)
        }
      }

      rafRef.current = requestAnimationFrame(animate)
    }

    rafRef.current = requestAnimationFrame(animate)

    return () => {
      if (rafRef.current) {
        cancelAnimationFrame(rafRef.current)
      }
    }
  }, [])

  return (
    <canvas
      ref={canvasRef}
      className="fixed inset-0 w-full h-full"
      style={{ background: theme === "light" ? "#f5f5f5" : "#000", touchAction: "none" }}
    />
  )
}
