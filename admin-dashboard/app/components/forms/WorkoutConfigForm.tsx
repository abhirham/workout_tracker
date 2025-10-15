'use client';

interface WorkoutConfigFormProps {
  workoutType: 'Weight' | 'Timer';
  config: {
    baseWeight?: number;
    targetReps?: number;
    numSets: number;
    restTimer?: number;
    workoutDuration?: number;
  };
  onChange: (config: any) => void;
}

export default function WorkoutConfigForm({ workoutType, config, onChange }: WorkoutConfigFormProps) {
  const handleChange = (field: string, value: number) => {
    onChange({ ...config, [field]: value });
  };

  return (
    <div className="bg-[#F8FAFC] rounded-lg p-6 space-y-4">
      <h3 className="text-[16px] font-semibold text-[#000000] mb-4">Workout Configuration</h3>

      <div className="grid grid-cols-2 gap-4">
        {workoutType === 'Weight' && (
          <>
            <div>
              <label htmlFor="baseWeight" className="block text-[13px] font-medium text-[#000000] mb-2">
                Base Weight (lbs)
              </label>
              <input
                type="number"
                id="baseWeight"
                min="0"
                step="0.5"
                value={config.baseWeight || 0}
                onChange={(e) => handleChange('baseWeight', parseFloat(e.target.value) || 0)}
                className="w-full px-3 py-2 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
                placeholder="10"
              />
            </div>

            <div>
              <label htmlFor="targetReps" className="block text-[13px] font-medium text-[#000000] mb-2">
                Target Reps
              </label>
              <input
                type="number"
                id="targetReps"
                min="1"
                value={config.targetReps || 12}
                onChange={(e) => handleChange('targetReps', parseInt(e.target.value) || 12)}
                className="w-full px-3 py-2 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
                placeholder="12"
              />
            </div>
          </>
        )}

        <div>
          <label htmlFor="numSets" className="block text-[13px] font-medium text-[#000000] mb-2">
            Number of Sets
          </label>
          <input
            type="number"
            id="numSets"
            min="1"
            value={config.numSets || 4}
            onChange={(e) => handleChange('numSets', parseInt(e.target.value) || 4)}
            className="w-full px-3 py-2 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
            placeholder="4"
          />
        </div>

        {workoutType === 'Weight' ? (
          <div>
            <label htmlFor="restTimer" className="block text-[13px] font-medium text-[#000000] mb-2">
              Rest Timer (seconds)
            </label>
            <input
              type="number"
              id="restTimer"
              min="0"
              value={config.restTimer || 0}
              onChange={(e) => handleChange('restTimer', parseInt(e.target.value) || 0)}
              className="w-full px-3 py-2 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
              placeholder="45"
            />
          </div>
        ) : (
          <div>
            <label htmlFor="workoutDuration" className="block text-[13px] font-medium text-[#000000] mb-2">
              Duration (seconds)
            </label>
            <input
              type="number"
              id="workoutDuration"
              min="1"
              value={config.workoutDuration || 60}
              onChange={(e) => handleChange('workoutDuration', parseInt(e.target.value) || 60)}
              className="w-full px-3 py-2 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
              placeholder="60"
            />
          </div>
        )}
      </div>
    </div>
  );
}
