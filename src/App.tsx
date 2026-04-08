/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { User, Home, Plus, MessageSquare, Camera } from 'lucide-react';

export default function App() {
  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 font-sans">
      {/* Header */}
      <header className="flex items-center justify-between p-4 bg-white border-b border-slate-100">
        <div className="flex items-center gap-2">
          <Camera className="w-6 h-6 text-blue-500" />
          <h1 className="text-xl font-bold text-slate-800">SnapTrackr</h1>
        </div>
        <div className="w-10 h-10 rounded-full bg-slate-200 flex items-center justify-center">
          <User className="w-6 h-6 text-slate-500" />
        </div>
      </header>

      {/* Main Content */}
      <main className="p-4 space-y-6">
        <section>
          <h2 className="text-3xl font-bold text-slate-900">Good morning. Pantry looks calm.</h2>
          <p className="text-slate-600 mt-1">Your inventory is managed and predictable today.</p>
        </section>

        {/* You might need soon */}
        <section>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-xl font-semibold">You might need soon</h3>
            <a href="#" className="text-blue-600 font-medium">View inventory</a>
          </div>
          <div className="space-y-4">
            {/* Milk Card */}
            <div className="bg-white p-4 rounded-2xl shadow-sm border border-slate-100 flex items-center gap-4">
              <div className="w-16 h-16 bg-slate-100 rounded-xl flex items-center justify-center">
                <img src="https://picsum.photos/seed/milk/64/64" alt="Milk" className="w-12 h-12" />
              </div>
              <div className="flex-1">
                <h4 className="font-semibold text-lg">Milk</h4>
                <p className="text-slate-500 text-sm">Likely needed in 2 days</p>
                <div className="flex gap-2 mt-2">
                  <button className="bg-blue-500 text-white px-4 py-1.5 rounded-full text-sm font-medium">Bought</button>
                  <button className="bg-slate-100 text-slate-700 px-4 py-1.5 rounded-full text-sm font-medium">Not yet</button>
                </div>
              </div>
            </div>
            {/* Eggs Card */}
            <div className="bg-white p-4 rounded-2xl shadow-sm border border-slate-100 flex items-center gap-4">
              <div className="w-16 h-16 bg-slate-100 rounded-xl flex items-center justify-center">
                <img src="https://picsum.photos/seed/eggs/64/64" alt="Eggs" className="w-12 h-12" />
              </div>
              <div className="flex-1">
                <h4 className="font-semibold text-lg">Eggs</h4>
                <p className="text-slate-500 text-sm">Running low soon</p>
                <div className="flex gap-2 mt-2">
                  <button className="bg-blue-500 text-white px-4 py-1.5 rounded-full text-sm font-medium">Bought</button>
                  <button className="bg-slate-100 text-slate-700 px-4 py-1.5 rounded-full text-sm font-medium">Not yet</button>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* This week */}
        <section>
          <h3 className="text-xl font-semibold mb-4">This week</h3>
          <div className="bg-white p-4 rounded-2xl shadow-sm border border-slate-100 space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-blue-50 rounded-full flex items-center justify-center text-blue-500">
                  <span className="text-sm">🌿</span>
                </div>
                <span className="font-medium">Spinach</span>
              </div>
              <span className="text-slate-500 text-sm">Due in 5 days</span>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-blue-50 rounded-full flex items-center justify-center text-blue-500">
                  <span className="text-sm">🍴</span>
                </div>
                <span className="font-medium">Pasta Sauce</span>
              </div>
              <span className="text-slate-500 text-sm">Due in 6 days</span>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-blue-50 rounded-full flex items-center justify-center text-blue-500">
                  <span className="text-sm">☕</span>
                </div>
                <span className="font-medium">Coffee Beans</span>
              </div>
              <span className="text-slate-500 text-sm">Due in 7 days</span>
            </div>
          </div>
        </section>

        {/* You're good */}
        <section className="bg-green-100 p-6 rounded-2xl border border-green-200">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-6 h-6 bg-green-500 rounded-full flex items-center justify-center text-white">
              <span className="text-xs">✓</span>
            </div>
            <h4 className="font-semibold text-green-900">You're good</h4>
          </div>
          <p className="text-green-800 text-sm mb-4">Everything else in your pantry is well-stocked for the weekend. No need to shop yet.</p>
          <a href="#" className="text-green-900 font-semibold text-sm flex items-center gap-1">Check full report →</a>
        </section>
      </main>

      {/* Bottom Nav */}
      <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-slate-100 p-4 flex justify-around items-center">
        <Home className="w-6 h-6 text-blue-500" />
        <div className="w-12 h-12 bg-slate-200 rounded-full flex items-center justify-center">
          <Plus className="w-6 h-6 text-slate-600" />
        </div>
        <MessageSquare className="w-6 h-6 text-slate-400" />
        <div className="absolute right-4 bottom-20 w-14 h-14 bg-blue-500 rounded-full flex items-center justify-center text-white shadow-lg">
          <Camera className="w-7 h-7" />
        </div>
      </nav>
    </div>
  );
}

