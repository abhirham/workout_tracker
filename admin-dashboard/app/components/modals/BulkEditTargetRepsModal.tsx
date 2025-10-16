'use client';

import { useState, useEffect } from 'react';

interface BulkEditTargetRepsModalProps {
  isOpen: boolean;
  onClose: () => void;
  onUpdate: (mapping: Record<string, string>) => void;
  weekNumber: number;
  currentValues: string[]; // Unique target rep values found in the week
}

export default function BulkEditTargetRepsModal({
  isOpen,
  onClose,
  onUpdate,
  weekNumber,
  currentValues,
}: BulkEditTargetRepsModalProps) {
  const [mapping, setMapping] = useState<Record<string, string>>({});

  useEffect(() => {
    if (isOpen) {
      // Reset mapping when modal opens
      setMapping({});
    }
  }, [isOpen]);

  const handleUpdate = () => {
    // Filter out empty values (user didn't provide a new value)
    const filteredMapping = Object.entries(mapping).reduce((acc, [key, value]) => {
      if (value.trim()) {
        acc[key] = value.trim();
      }
      return acc;
    }, {} as Record<string, string>);

    onUpdate(filteredMapping);
    onClose();
  };

  const handleInputChange = (currentValue: string, newValue: string) => {
    setMapping(prev => ({
      ...prev,
      [currentValue]: newValue,
    }));
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className="fixed inset-0 bg-black/30 backdrop-blur-sm transition-opacity"
          onClick={onClose}
        ></div>
        <div className="relative bg-white rounded-2xl shadow-xl w-full max-w-lg p-8">
          {/* Header */}
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-[24px] font-bold text-[#000000]">
                Edit Target Reps
              </h3>
              <p className="text-[14px] text-[#64748B] mt-1">
                Update target reps for Week {weekNumber}
              </p>
            </div>
            <button
              onClick={onClose}
              className="w-10 h-10 rounded-full hover:bg-[#F1F5F9] flex items-center justify-center transition-colors"
            >
              <svg className="w-6 h-6 text-[#64748B]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          {/* Info Message */}
          <div className="mb-6 p-4 bg-[#F8FAFC] border border-[#E2E8F0] rounded-lg">
            <p className="text-[13px] text-[#64748B]">
              Found <span className="font-semibold text-[#000000]">{currentValues.length}</span> unique target rep{currentValues.length !== 1 ? ' values' : ' value'} in this week.
              Leave a field empty to keep the current value.
            </p>
          </div>

          {/* Mapping List */}
          <div className="space-y-4 mb-6">
            {currentValues.length > 0 ? (
              currentValues.map((value) => (
                <div key={value} className="flex items-center gap-4">
                  {/* Current Value */}
                  <div className="flex-1">
                    <label className="block text-[12px] font-medium text-[#64748B] mb-1">
                      Current Value
                    </label>
                    <div className="px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-[#F8FAFC] text-[#000000] font-semibold">
                      {value}
                    </div>
                  </div>

                  {/* Arrow */}
                  <div className="pt-6">
                    <svg className="w-5 h-5 text-[#94A3B8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                    </svg>
                  </div>

                  {/* New Value Input */}
                  <div className="flex-1">
                    <label htmlFor={`new-${value}`} className="block text-[12px] font-medium text-[#64748B] mb-1">
                      New Value
                    </label>
                    <input
                      type="text"
                      id={`new-${value}`}
                      value={mapping[value] || ''}
                      onChange={(e) => handleInputChange(value, e.target.value)}
                      placeholder="e.g., 10-12"
                      className="w-full px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
                    />
                  </div>
                </div>
              ))
            ) : (
              <div className="text-center py-8 text-[#94A3B8]">
                <p className="text-[14px]">No target rep values found in this week.</p>
              </div>
            )}
          </div>

          {/* Footer Actions */}
          <div className="flex items-center justify-end gap-3 pt-6 border-t border-[#E2E8F0]">
            <button
              onClick={onClose}
              className="px-6 py-2.5 text-[14px] font-medium text-[#64748B] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleUpdate}
              disabled={currentValues.length === 0}
              className="px-6 py-2.5 text-[14px] font-medium text-white bg-[#0F172A] rounded-lg hover:bg-[#1E293B] transition-colors disabled:bg-[#E2E8F0] disabled:text-[#94A3B8] disabled:cursor-not-allowed"
            >
              Update
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
