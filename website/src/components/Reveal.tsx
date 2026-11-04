import { motion } from 'motion/react';
import type { ElementType, ReactNode } from 'react';

/** Fades and floats its children in once, as they scroll into view. Honours reduced-motion (see MotionConfig in App). */
export function Reveal({
  children,
  delay = 0,
  className,
  as = 'div',
}: {
  children: ReactNode;
  delay?: number;
  className?: string;
  as?: 'div' | 'li' | 'section' | 'p';
}) {
  if (typeof window === 'undefined') {
    const Tag = as as ElementType;
    return <Tag className={className}>{children}</Tag>;
  }
  const M = motion[as];
  return (
    <M
      className={className}
      initial={{ opacity: 0, y: 22 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '0px 0px -12% 0px' }}
      transition={{ duration: 0.7, delay, ease: [0.22, 1, 0.36, 1] }}
    >
      {children}
    </M>
  );
}
